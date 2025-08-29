/**
 * @file mongory_ext.c
 * @brief Ruby C extension wrapper for mongory-core
 *
 * This file provides Ruby bindings for the mongory-core C library,
 * allowing Ruby applications to use high-performance C-based matching
 * operations while maintaining the elegant Ruby DSL.
 */
#include "mongory-core.h"
#include <ruby.h>
#include <ruby/encoding.h>
#include <string.h>

// Ruby module and class definitions
static VALUE mMongory;
static VALUE cMongoryMatcher;
static VALUE cMongoryMatcherContext;
static VALUE mMongoryMatchers;

// Error classes
static VALUE eMongoryError;
static VALUE eMongoryTypeError;

// Converter instance
static VALUE inMongoryDataConverter;
static VALUE inMongoryConditionConverter;

// Matcher wrapper structure
typedef struct rb_mongory_matcher_t {
  mongory_matcher *matcher;
  mongory_value *condition;
  mongory_memory_pool *pool;
  mongory_memory_pool *scratch_pool;
  mongory_memory_pool *trace_pool;
  mongory_table *string_map;
  mongory_table *symbol_map;
  mongory_array *mark_list;
  VALUE ctx;
} rb_mongory_matcher_t;

typedef struct rb_mongory_memory_pool_t {
  mongory_memory_pool base;
  rb_mongory_matcher_t *owner;
} rb_mongory_memory_pool_t;

typedef struct rb_mongory_table_t {
  mongory_table base;
  VALUE rb_hash;
  rb_mongory_matcher_t *owner;
} rb_mongory_table_t;

typedef struct rb_mongory_array_t {
  mongory_array base;
  VALUE rb_array;
  rb_mongory_matcher_t *owner;
} rb_mongory_array_t;

typedef struct {
  mongory_table *table;
  mongory_memory_pool *pool;
} hash_conv_ctx;

// Forward declarations
static void rb_mongory_matcher_mark(void *ptr);
static void rb_mongory_matcher_free(void *ptr);
mongory_value *rb_to_mongory_value_deep(mongory_memory_pool *pool, VALUE rb_value);
mongory_value *rb_to_mongory_value_shallow(mongory_memory_pool *pool, VALUE rb_value);
mongory_value *rb_mongory_table_wrap(mongory_memory_pool *pool, VALUE rb_hash);
mongory_value *rb_mongory_array_wrap(mongory_memory_pool *pool, VALUE rb_array);
static VALUE cache_fetch_string(rb_mongory_matcher_t *owner, const char *key);
static VALUE cache_fetch_symbol(rb_mongory_matcher_t *owner, const char *key);
static rb_mongory_memory_pool_t *rb_mongory_memory_pool_new();
static void rb_mongory_matcher_parse_argv(rb_mongory_matcher_t *wrapper, int argc, VALUE *argv);
static bool rb_mongory_error_handling(mongory_memory_pool *pool, char *error_message);

static const rb_data_type_t rb_mongory_matcher_type = {
  .wrap_struct_name = "mongory_matcher",
  .function = {
    .dmark = rb_mongory_matcher_mark,
    .dfree = rb_mongory_matcher_free,
    .dsize = NULL,
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

/**
 * Ruby method implementations
 */

// Mongory::CMatcher.new(condition)
static VALUE rb_mongory_matcher_new(int argc, VALUE *argv, VALUE class) {
  rb_mongory_memory_pool_t *matcher_pool = rb_mongory_memory_pool_new();
  mongory_memory_pool *matcher_pool_base = &matcher_pool->base;
  rb_mongory_memory_pool_t *scratch_pool = rb_mongory_memory_pool_new();
  mongory_memory_pool *scratch_pool_base = &scratch_pool->base;
  rb_mongory_matcher_t *wrapper = ALLOC(rb_mongory_matcher_t);
  wrapper->pool = matcher_pool_base;
  wrapper->scratch_pool = scratch_pool_base;
  wrapper->trace_pool = NULL;
  wrapper->ctx = NULL;
  wrapper->string_map = mongory_table_new(matcher_pool_base);
  wrapper->symbol_map = mongory_table_new(matcher_pool_base);
  wrapper->mark_list = mongory_array_new(matcher_pool_base);
  wrapper->condition = NULL;
  wrapper->matcher = NULL;
  matcher_pool->owner = wrapper;
  scratch_pool->owner = wrapper;
  rb_mongory_matcher_parse_argv(wrapper, argc, argv);

  mongory_matcher *matcher = mongory_matcher_new(matcher_pool_base, wrapper->condition, wrapper->ctx);
  if (rb_mongory_error_handling(matcher_pool_base, "Failed to create matcher")) {
    matcher_pool_base->free(matcher_pool_base);
    scratch_pool_base->free(scratch_pool_base);
    xfree(wrapper);
    return Qnil;
  }

  wrapper->matcher = matcher;
  return TypedData_Wrap_Struct(class, &rb_mongory_matcher_type, wrapper);
}

static void rb_mongory_matcher_parse_argv(rb_mongory_matcher_t *self, int argc, VALUE *argv) {
  VALUE condition, kw_hash;
  rb_scan_args(argc, argv, "1:", &condition, &kw_hash);
  const ID ctx_id[1] = { rb_intern("context") };
  VALUE kw_vals[1] = { Qundef };
  if (kw_hash != Qnil) {
    rb_get_kwargs(kw_hash, ctx_id, 1, 0, kw_vals);
  }
  if (kw_vals[0] != Qundef) {
    self->ctx = kw_vals[0];
  } else {
    self->ctx = rb_funcall(cMongoryMatcherContext, rb_intern("new"), 0);
  }
  VALUE converted_condition = rb_funcall(inMongoryConditionConverter, rb_intern("convert"), 1, condition);
  self->condition = rb_to_mongory_value_deep(self->pool, converted_condition);
  self->mark_list->push(self->mark_list, self->condition);
  mongory_value *store_ctx = mongory_value_wrap_u(self->pool, (void *)self->ctx);
  store_ctx->origin = (void *)self->ctx;
  self->mark_list->push(self->mark_list, store_ctx);
}

// Mongory::CMatcher#match(data)
static VALUE rb_mongory_matcher_match(VALUE self, VALUE data) {
  rb_mongory_matcher_t *self_wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, self_wrapper);
  mongory_matcher *matcher = self_wrapper->matcher;
  mongory_memory_pool *scratch_pool = self_wrapper->scratch_pool;
  mongory_memory_pool *trace_pool = self_wrapper->trace_pool;
  mongory_value *data_value = rb_to_mongory_value_shallow(scratch_pool, data);

  if (rb_mongory_error_handling(scratch_pool, "Match failed")) {
    return Qnil;
  }

  bool result = mongory_matcher_match(matcher, data_value);

  if (trace_pool) {
    mongory_matcher_print_trace(matcher);
    trace_pool->reset(trace_pool);
    mongory_matcher_enable_trace(matcher, trace_pool);
  }

  scratch_pool->reset(scratch_pool);

  return result ? Qtrue : Qfalse;
}

// Mongory::CMatcher#explain
static VALUE rb_mongory_matcher_explain(VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  mongory_matcher_explain(wrapper->matcher, wrapper->scratch_pool);
  if (rb_mongory_error_handling(wrapper->scratch_pool, "Explain failed")) {
    return Qnil;
  }
  wrapper->scratch_pool->reset(wrapper->scratch_pool);
  return Qnil;
}

// Mongory::CMatcher#trace(data)
static VALUE rb_mongory_matcher_trace(VALUE self, VALUE data) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  mongory_memory_pool *trace_pool = mongory_memory_pool_new();
  mongory_value *data_value = rb_to_mongory_value_shallow(trace_pool, data);

  if (rb_mongory_error_handling(trace_pool, "Trace failed")) {
    trace_pool->free(trace_pool);
    return Qnil;
  }

  bool matched = mongory_matcher_trace(wrapper->matcher, data_value);
  trace_pool->free(trace_pool);

  return matched ? Qtrue : Qfalse;
}

// Mongory::CMatcher#enable_trace
static VALUE rb_mongory_matcher_enable_trace(VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  mongory_memory_pool *trace_pool = rb_mongory_memory_pool_new();
  mongory_matcher_enable_trace(wrapper->matcher, trace_pool);

  if (rb_mongory_error_handling(trace_pool, "Enable trace failed")) {
    trace_pool->free(trace_pool);
    return Qnil;
  }
  wrapper->trace_pool = trace_pool;

  return Qnil;
}

// Mongory::CMatcher#disable_trace
static VALUE rb_mongory_matcher_disable_trace(VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  mongory_memory_pool *trace_pool = wrapper->trace_pool;
  mongory_matcher_disable_trace(wrapper->matcher);
  rb_mongory_error_handling(trace_pool, "Disable trace failed");
  trace_pool->free(trace_pool);
  wrapper->trace_pool = NULL;

  return Qnil;
}

// Mongory::CMatcher#print_trace
static VALUE rb_mongory_matcher_print_trace(VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  mongory_matcher_print_trace(wrapper->matcher);
  rb_mongory_error_handling(wrapper->trace_pool, "Print trace failed");

  return Qnil;
}

// Mongory::CMatcher#condition
static VALUE rb_mongory_matcher_condition(VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);

  return (VALUE)wrapper->condition->origin;
}

// Mongory::CMatcher#context
static VALUE rb_mongory_matcher_context(VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);

  return wrapper->ctx ? wrapper->ctx : Qnil;
}

// Mongory::CMatcher.trace_result_colorful=(colorful)
static VALUE rb_mongory_matcher_trace_result_colorful(VALUE self, VALUE colorful) {
  (void)self;
  mongory_matcher_trace_result_colorful_set(RTEST(colorful));

  return Qnil;
}

/**
 * Create a new memory pool
 */
static rb_mongory_memory_pool_t *rb_mongory_memory_pool_new() {
  rb_mongory_memory_pool_t *pool = malloc(sizeof(rb_mongory_memory_pool_t));
  mongory_memory_pool *base = mongory_memory_pool_new();
  memcpy(&pool->base, base, sizeof(mongory_memory_pool));
  free(base);

  return pool;
}

/**
 * Ruby GC management functions
 */
static void rb_mongory_matcher_free(void *ptr) {
  rb_mongory_matcher_t *wrapper = (rb_mongory_matcher_t *)ptr;
  mongory_memory_pool *pool = wrapper->pool;
  mongory_memory_pool *scratch_pool = wrapper->scratch_pool;
  mongory_memory_pool *trace_pool = wrapper->trace_pool;
  pool->free(pool);
  scratch_pool->free(scratch_pool);
  if (trace_pool) {
    trace_pool->free(trace_pool);
  }
  xfree(wrapper);
}

/**
 * GC marking callback for mongory_array
 */
static bool gc_mark_array_cb(mongory_value *value, void *acc) {
  (void)acc;
  if (value && value->origin) rb_gc_mark((VALUE)value->origin);
  return true;
}

/**
 * GC marking callback for mongory_matcher
 */
static void rb_mongory_matcher_mark(void *ptr) {
  rb_mongory_matcher_t *self = (rb_mongory_matcher_t *)ptr;
  if (!self) return;
  self->mark_list->each(self->mark_list, NULL, gc_mark_array_cb);
}

/**
 * Helper functions for Ruby/C conversion
 */

// Helper function to convert Ruby value to C string
static char *rb_mongory_value_to_cstr(mongory_value *value, mongory_memory_pool *pool) {
  (void)pool;
  VALUE rb_value = (VALUE)value->origin;
  VALUE rb_str = rb_funcall(rb_value, rb_intern("inspect"), 0);
  return StringValueCStr(rb_str);
}

// Helper function for primitive conversion of Ruby value to mongory_value
static mongory_value *rb_to_mongory_value_primitive(mongory_memory_pool *pool, VALUE rb_value) {
  mongory_value *mg_value = NULL;
  switch (TYPE(rb_value)) {
  case T_NIL:
    mg_value = mongory_value_wrap_n(pool, NULL);
    break;

  case T_TRUE:
    mg_value = mongory_value_wrap_b(pool, true);
    break;

  case T_FALSE:
    mg_value = mongory_value_wrap_b(pool, false);
    break;

  case T_FIXNUM:
    mg_value = mongory_value_wrap_i(pool, rb_num2long_inline(rb_value));
    break;

  case T_BIGNUM:
    mg_value = mongory_value_wrap_i(pool, rb_num2ll_inline(rb_value));
    break;

  case T_FLOAT:
    mg_value = mongory_value_wrap_d(pool, rb_num2dbl(rb_value));
    break;

  case T_STRING:
    mg_value = mongory_value_wrap_s(pool, StringValueCStr(rb_value));
    break;

  case T_SYMBOL:
    mg_value = mongory_value_wrap_s(pool, (char *)rb_id2name(rb_sym2id(rb_value)));
    break;

  case T_REGEXP:
    mg_value = mongory_value_wrap_regex(pool, (void *)rb_value);
    break;
  }
  return mg_value;
}
// Shallow conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
static mongory_value *rb_to_mongory_value_shallow_rec(mongory_memory_pool *pool, VALUE rb_value, bool converted) {
  mongory_value *mg_value = rb_to_mongory_value_primitive(pool, rb_value);
  if (mg_value) {
    mg_value->origin = rb_value;
    return mg_value;
  }

  switch (TYPE(rb_value)) {
  case T_ARRAY: {
    mg_value = rb_mongory_array_wrap(pool, rb_value);
    break;
  }

  case T_HASH: {
    mg_value = rb_mongory_table_wrap(pool, rb_value);
    break;
  }

  default:
    if (converted) {
      mg_value = mongory_value_wrap_u(pool, (void *)rb_value);
      break;
    } else {
      VALUE converted_value = rb_funcall(inMongoryDataConverter, rb_intern("convert"), 1, rb_value);
      return rb_to_mongory_value_shallow_rec(pool, converted_value, true);
    }
  }
  mg_value->origin = rb_value;
  return mg_value;
}

// Shallow conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
mongory_value *rb_to_mongory_value_shallow(mongory_memory_pool *pool, VALUE rb_value) {
  return rb_to_mongory_value_shallow_rec(pool, rb_value, false);
}

// Helper function for deep conversion of hash values
static int hash_foreach_deep_convert_cb(VALUE key, VALUE val, VALUE ptr) {
  hash_conv_ctx *ctx = (hash_conv_ctx *)ptr;
  rb_mongory_memory_pool_t *rb_pool = (rb_mongory_memory_pool_t *)ctx->pool;
  rb_mongory_matcher_t *owner = rb_pool->owner;
  mongory_table *store_map;
  char *key_str;
  if (SYMBOL_P(key)) {
    key_str = (char *)rb_id2name(SYM2ID(key));
    store_map = owner->symbol_map;
  } else {
    key_str = StringValueCStr(key);
    store_map = owner->string_map;
  }
  mongory_value *store = mongory_value_wrap_u(ctx->pool, NULL);
  store->origin = (void *)key;
  store_map->set(store_map, key_str, store);
  mongory_value *cval = rb_to_mongory_value_deep(ctx->pool, val);
  ctx->table->set(ctx->table, key_str, cval);
  return ST_CONTINUE;
}

// Deep conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
static mongory_value *rb_to_mongory_value_deep_rec(mongory_memory_pool *pool, VALUE rb_value, bool converted) {
  mongory_value *mg_value = rb_to_mongory_value_primitive(pool, rb_value);
  if (mg_value) {
    mg_value->origin = rb_value;
    return mg_value;
  }
  switch (TYPE(rb_value)) {
  case T_ARRAY: {
    mongory_array *array = mongory_array_new(pool);

    for (long i = 0; i < RARRAY_LEN(rb_value); i++) {
      array->push(array, rb_to_mongory_value_deep(pool, RARRAY_AREF(rb_value, i)));
    }
    mg_value = mongory_value_wrap_a(pool, array);
    break;
  }

  case T_HASH: {
    mongory_table *table = mongory_table_new(pool);

    hash_conv_ctx ctx = {table, pool};
    rb_hash_foreach(rb_value, hash_foreach_deep_convert_cb, (VALUE)&ctx);

    mg_value = mongory_value_wrap_t(pool, table);
    break;
  }

  default:
    if (converted) {
      mg_value = mongory_value_wrap_u(pool, (void *)rb_value);
      break;
    } else {
      VALUE converted_value = rb_funcall(inMongoryDataConverter, rb_intern("convert"), 1, rb_value);
      mg_value = rb_to_mongory_value_deep_rec(pool, converted_value, true);
      break;
    }
  }
  mg_value->origin = rb_value;
  return mg_value;
}

// Deep conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
mongory_value *rb_to_mongory_value_deep(mongory_memory_pool *pool, VALUE rb_value) {
  return rb_to_mongory_value_deep_rec(pool, rb_value, false);
}

// Get value from Ruby hash via mongory_table
mongory_value *rb_mongory_table_get(mongory_table *self, char *key) {
  rb_mongory_table_t *table = (rb_mongory_table_t *)self;
  VALUE rb_hash = table->rb_hash;
  VALUE rb_value = Qundef;

  // Use cached Ruby String key if possible
  VALUE key_str = cache_fetch_string(table->owner, key);
  rb_value = rb_hash_lookup2(rb_hash, key_str, Qundef);

  if (rb_value == Qundef) {
    // Fallback to Symbol key, using cache
    VALUE key_sym = cache_fetch_symbol(table->owner, key);
    rb_value = rb_hash_lookup2(rb_hash, key_sym, Qundef);
  }

  if (rb_value == Qundef) {
    return NULL;
  }
  return rb_to_mongory_value_shallow(table->base.pool, rb_value);
}

// Shallow conversion: Wrap Ruby hash as mongory_table
mongory_value *rb_mongory_table_wrap(mongory_memory_pool *pool, VALUE rb_hash) {
  rb_mongory_table_t *table = MG_ALLOC_PTR(pool, rb_mongory_table_t);
  rb_mongory_memory_pool_t *rb_pool = (rb_mongory_memory_pool_t *)pool;
  table->base.pool = pool;
  table->base.get = rb_mongory_table_get;
  table->rb_hash = rb_hash;
  table->base.count = RHASH_SIZE(rb_hash);
  table->owner = rb_pool->owner;
  mongory_value *mg_value = mongory_value_wrap_t(pool, &table->base);
  mg_value->origin = (void *)rb_hash;
  mg_value->to_str = rb_mongory_value_to_cstr;
  return mg_value;
}

// Get value from Ruby array via mongory_array
static mongory_value *rb_mongory_array_get(mongory_array *self, size_t index) {
  rb_mongory_array_t *array = (rb_mongory_array_t *)self;
  VALUE rb_array = array->rb_array;
  if (index >= (size_t)RARRAY_LEN(rb_array)) {
    return NULL;
  }
  VALUE rb_value = rb_ary_entry(rb_array, index);
  return rb_to_mongory_value_shallow(self->pool, rb_value);
}

// Shallow conversion: Wrap Ruby array as mongory_array
mongory_value *rb_mongory_array_wrap(mongory_memory_pool *pool, VALUE rb_array) {
  rb_mongory_array_t *array = MG_ALLOC_PTR(pool, rb_mongory_array_t);
  rb_mongory_memory_pool_t *rb_pool = (rb_mongory_memory_pool_t *)pool;
  array->base.pool = pool;
  array->base.get = rb_mongory_array_get;
  array->rb_array = rb_array;
  array->base.count = RARRAY_LEN(rb_array);
  array->owner = rb_pool->owner;
  mongory_value *mg_value = mongory_value_wrap_a(pool, &array->base);
  mg_value->origin = (void *)rb_array;
  mg_value->to_str = rb_mongory_value_to_cstr;
  return mg_value;
}

// Convert mongory_value to Ruby value (returns the original Ruby value where binding in below conversion is needed)
void *mongory_value_to_ruby(mongory_memory_pool *pool, mongory_value *value) {
  (void)pool;
  if (!value)
    return NULL;
  return value->origin;
}

// ===== Cache helper implementations =====
static VALUE cache_fetch_string(rb_mongory_matcher_t *owner, const char *key) {
  if (!owner || !owner->string_map) return rb_utf8_str_new_cstr(key);
  mongory_value *v = owner->string_map->get(owner->string_map, (char *)key);
  if (v && v->origin) return (VALUE)v->origin;
  VALUE s = rb_utf8_str_new_cstr(key);
  mongory_value *store = mongory_value_wrap_u(owner->pool, NULL);
  store->origin = (void *)s;
  owner->string_map->set(owner->string_map, (char *)key, store);
  owner->mark_list->push(owner->mark_list, store);
  return s;
}

// Helper function to convert char* key to Ruby symbol
static inline VALUE char_key_to_symbol(const char *key, rb_encoding *enc) {
  ID id = rb_check_id_cstr(key, (long)strlen(key), enc);
  if (!id) id = rb_intern3(key, (long)strlen(key), enc);
  return ID2SYM(id);
}

// Cache helper for Ruby symbol keys
static VALUE cache_fetch_symbol(rb_mongory_matcher_t *owner, const char *key) {
  rb_encoding *enc = rb_utf8_encoding();
  if (!owner || !owner->symbol_map) {
    return char_key_to_symbol(key, enc);
  }
  mongory_value *v = owner->symbol_map->get(owner->symbol_map, (char *)key);
  if (v && v->origin) return (VALUE)v->origin;
  VALUE sym = char_key_to_symbol(key, enc);
  mongory_value *store = mongory_value_wrap_u(owner->pool, NULL);
  store->origin = (void *)sym;
  owner->symbol_map->set(owner->symbol_map, (char *)key, store);
  owner->mark_list->push(owner->mark_list, store);
  return sym;
}

// Regex adapter bridging to Ruby's Regexp
static bool rb_mongory_regex_match_adapter(mongory_memory_pool *pool, mongory_value *pattern, mongory_value *value) {
  if (!pattern || !value) {
    return false;
  }
  if (value->type != MONGORY_TYPE_STRING) {
    return false;
  }

  VALUE rb_str = (VALUE)value->origin;
  VALUE rb_re = Qnil;

  if (pattern->type == MONGORY_TYPE_REGEX && pattern->data.regex) {
    rb_re = (VALUE)pattern->data.regex;
  } else if (pattern->type == MONGORY_TYPE_STRING) {
    rb_re = rb_funcall(rb_cRegexp, rb_intern("new"), 1, (VALUE)pattern->origin);
    mongory_value *temp_value = mongory_value_wrap_regex(pool, (void *)rb_re);
    memcpy(pattern, temp_value, sizeof(mongory_value));
    pattern->origin = (void *)rb_re;
  } else {
    return false;
  }

  VALUE matched = rb_funcall(rb_re, rb_intern("match?"), 1, rb_str);
  return RTEST(matched);
}

// Regex adapter bridging to Ruby's Regexp
static char *rb_mongory_regex_stringify_adapter(mongory_memory_pool *pool, mongory_value *pattern) {
  (void)pool;
  if (pattern->type != MONGORY_TYPE_REGEX) {
    return NULL;
  }
  VALUE rb_re = (VALUE)pattern->data.regex;
  VALUE rb_str = rb_funcall(rb_re, rb_intern("inspect"), 0);
  return StringValueCStr(rb_str);
}

// Custom matcher adapter bridging to Ruby's custom matcher
static mongory_matcher_custom_context *rb_mongory_custom_matcher_build(char *key, mongory_value *condition, void *ctx) {
  mongory_memory_pool *pool = condition->pool;
  rb_mongory_memory_pool_t *rb_pool = (rb_mongory_memory_pool_t *)pool;
  rb_mongory_matcher_t *owner = rb_pool->owner;
  VALUE matcher_class = rb_funcall(mMongoryMatchers, rb_intern("lookup"), 1, cache_fetch_string(owner, key));
  if (matcher_class == Qnil) {
    return NULL;
  }
  VALUE kw_hash = rb_hash_new();
  rb_hash_aset(kw_hash, ID2SYM(rb_intern("context")), (VALUE)ctx);

  #ifdef RB_PASS_KEYWORDS
    VALUE argv_new[2] = { (VALUE)condition->origin, kw_hash };
    VALUE matcher = rb_funcallv_kw(matcher_class, rb_intern("new"), 2, argv_new, RB_PASS_KEYWORDS);
  #else
    VALUE matcher = rb_funcall(matcher_class, rb_intern("new"), 2, (VALUE)condition->origin, kw_hash);
  #endif

  if (matcher == Qnil) {
    return NULL;
  }
  mongory_value *matcher_value = mongory_value_wrap_u(pool, NULL);
  matcher_value->origin = (void *)matcher;
  owner->mark_list->push(owner->mark_list, matcher_value);
  VALUE class_name = rb_funcall(matcher_class, rb_intern("name"), 0);
  mongory_matcher_custom_context *return_ctx = MG_ALLOC_PTR(pool, mongory_matcher_custom_context);
  if (return_ctx == NULL) {
    return NULL;
  }
  return_ctx->name = StringValueCStr(class_name);
  return_ctx->external_matcher = (void *)matcher;
  return return_ctx;
}

// Custom matcher adapter bridging to Ruby's custom matcher
static bool rb_mongory_custom_matcher_match(void *ruby_matcher, mongory_value *value) {
  VALUE matcher = (VALUE)ruby_matcher;
  VALUE match_result = rb_funcall(matcher, rb_intern("match?"), 1, value->origin);
  return RTEST(match_result);
}

// Custom matcher adapter bridging to Ruby's custom matcher
static bool rb_mongory_custom_matcher_lookup(char *key) {
  VALUE matcher_class = rb_funcall(mMongoryMatchers, rb_intern("lookup"), 1, rb_str_new_cstr(key));
  return RTEST(matcher_class);
}

// Error handling for mongory_memory_pool
static bool rb_mongory_error_handling(mongory_memory_pool *pool, char *error_message) {
  if (pool->error) {
    rb_raise(eMongoryTypeError, "%s: %s", error_message, pool->error->message);
    pool->error = NULL;
    return true;
  }
  return false;
}

/**
 * Extension initialization
 */
void Init_mongory_ext(void) {
  // Initialize mongory core
  mongory_init();

  // Define modules and classes
  mMongory = rb_define_module("Mongory");
  cMongoryMatcher = rb_define_class_under(mMongory, "CMatcher", rb_cObject);
  mMongoryMatchers = rb_define_module_under(mMongory, "Matchers");
  VALUE mMongoryUtils = rb_define_module_under(mMongory, "Utils");
  cMongoryMatcherContext = rb_define_class_under(mMongoryUtils, "Context", rb_cObject);
  // Mongory converters
  inMongoryDataConverter = rb_funcall(mMongory, rb_intern("data_converter"), 0);
  inMongoryConditionConverter = rb_funcall(mMongory, rb_intern("condition_converter"), 0);

  // Define error classes
  eMongoryError = rb_define_class_under(mMongory, "Error", rb_eStandardError);
  eMongoryTypeError = rb_define_class_under(mMongory, "TypeError", eMongoryError);

  // Define Matcher methods
  rb_define_singleton_method(cMongoryMatcher, "new", rb_mongory_matcher_new, -1);
  rb_define_singleton_method(cMongoryMatcher, "trace_result_colorful=", rb_mongory_matcher_trace_result_colorful, 1);
  rb_define_method(cMongoryMatcher, "match?", rb_mongory_matcher_match, 1);
  rb_define_method(cMongoryMatcher, "explain", rb_mongory_matcher_explain, 0);
  rb_define_method(cMongoryMatcher, "condition", rb_mongory_matcher_condition, 0);
  rb_define_method(cMongoryMatcher, "context", rb_mongory_matcher_context, 0);
  rb_define_method(cMongoryMatcher, "trace", rb_mongory_matcher_trace, 1);
  rb_define_method(cMongoryMatcher, "enable_trace", rb_mongory_matcher_enable_trace, 0);
  rb_define_method(cMongoryMatcher, "disable_trace", rb_mongory_matcher_disable_trace, 0);
  rb_define_method(cMongoryMatcher, "print_trace", rb_mongory_matcher_print_trace, 0);

  // Set regex adapter to use Ruby's Regexp
  mongory_regex_func_set(rb_mongory_regex_match_adapter);
  mongory_regex_stringify_func_set(rb_mongory_regex_stringify_adapter);

  // Set value converter functions
  mongory_value_converter_deep_convert_set(rb_to_mongory_value_deep);
  mongory_value_converter_shallow_convert_set(rb_to_mongory_value_shallow);
  mongory_value_converter_recover_set(mongory_value_to_ruby);

  // Set custom matcher adapter
  mongory_custom_matcher_match_func_set(rb_mongory_custom_matcher_match);
  mongory_custom_matcher_build_func_set(rb_mongory_custom_matcher_build);
  mongory_custom_matcher_lookup_func_set(rb_mongory_custom_matcher_lookup);
}
