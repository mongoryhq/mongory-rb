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
static VALUE cMongoryMatchers;

// Error classes
static VALUE eMongoryError;
static VALUE eMongoryTypeError;

// Converter instance
static VALUE cMongoryDataConverter;
static VALUE cMongoryConditionConverter;

// Matcher wrapper structure
typedef struct ruby_mongory_matcher_t {
  mongory_matcher *matcher;
  mongory_value *condition;
  mongory_memory_pool *pool;
  mongory_memory_pool *scratch_pool;
  mongory_table *string_map;
  mongory_table *symbol_map;
  mongory_array *mark_list;
} ruby_mongory_matcher_t;

typedef struct ruby_mongory_memory_pool_t {
  mongory_memory_pool base;
  ruby_mongory_matcher_t *owner;
} ruby_mongory_memory_pool_t;

typedef struct ruby_mongory_table_t {
  mongory_table base;
  VALUE rb_hash;
  ruby_mongory_matcher_t *owner;
} ruby_mongory_table_t;

typedef struct ruby_mongory_array_t {
  mongory_array base;
  VALUE rb_array;
  ruby_mongory_matcher_t *owner;
} ruby_mongory_array_t;

typedef struct {
  mongory_table *table;
  mongory_memory_pool *pool;
} hash_conv_ctx;

// Forward declarations
static void ruby_mongory_matcher_mark(void *ptr);
static void ruby_mongory_matcher_free(void *ptr);
mongory_value *ruby_to_mongory_value_deep(mongory_memory_pool *pool, VALUE rb_value);
mongory_value *ruby_mongory_table_wrap(mongory_memory_pool *pool, VALUE rb_hash);
mongory_value *ruby_mongory_array_wrap(mongory_memory_pool *pool, VALUE rb_array);
mongory_value *ruby_to_mongory_value_shallow(mongory_memory_pool *pool, VALUE rb_value);
static VALUE cache_fetch_string(ruby_mongory_matcher_t *owner, const char *key);
static VALUE cache_fetch_symbol(ruby_mongory_matcher_t *owner, const char *key);
static ruby_mongory_memory_pool_t *ruby_mongory_memory_pool_new();

static const rb_data_type_t ruby_mongory_matcher_type = {
  .wrap_struct_name = "mongory_matcher",
  .function = {
    .dmark = ruby_mongory_matcher_mark,
    .dfree = ruby_mongory_matcher_free,
    .dsize = NULL,
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

/**
 * Ruby method implementations
 */

// Mongory::CMatcher.new(condition)
static VALUE ruby_mongory_matcher_new(VALUE class, VALUE condition) {
  ruby_mongory_memory_pool_t *matcher_pool = ruby_mongory_memory_pool_new();
  ruby_mongory_memory_pool_t *scratch_pool = ruby_mongory_memory_pool_new();
  ruby_mongory_matcher_t *wrapper = ALLOC(ruby_mongory_matcher_t);
  wrapper->pool = &matcher_pool->base;
  wrapper->scratch_pool = &scratch_pool->base;
  wrapper->string_map = mongory_table_new(&matcher_pool->base);
  wrapper->symbol_map = mongory_table_new(&matcher_pool->base);
  wrapper->mark_list = mongory_array_new(&matcher_pool->base);
  matcher_pool->owner = wrapper;
  scratch_pool->owner = wrapper;
  VALUE converted_condition = rb_funcall(cMongoryConditionConverter, rb_intern("convert"), 1, condition);
  wrapper->condition = ruby_to_mongory_value_deep(&matcher_pool->base, converted_condition);
  mongory_matcher *matcher = mongory_matcher_new(&matcher_pool->base, wrapper->condition);
  if (matcher_pool->base.error) {
    rb_raise(eMongoryError, "Failed to create matcher: %s", matcher_pool->base.error->message);
  }

  wrapper->matcher = matcher;
  return TypedData_Wrap_Struct(class, &ruby_mongory_matcher_type, wrapper);
}

// Mongory::CMatcher#match(data)
static VALUE ruby_mongory_matcher_match(VALUE self, VALUE data) {
  ruby_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, ruby_mongory_matcher_t, &ruby_mongory_matcher_type, wrapper);

  mongory_value *data_value = ruby_to_mongory_value_shallow(wrapper->scratch_pool, data);
  bool result = mongory_matcher_match(wrapper->matcher, data_value);
  wrapper->scratch_pool->reset(wrapper->scratch_pool->ctx);
  return result ? Qtrue : Qfalse;
}

// Mongory::CMatcher#explain
static VALUE ruby_mongory_matcher_explain(VALUE self) {
  ruby_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, ruby_mongory_matcher_t, &ruby_mongory_matcher_type, wrapper);
  mongory_matcher_explain(wrapper->matcher, wrapper->scratch_pool);
  wrapper->scratch_pool->reset(wrapper->scratch_pool->ctx);
  return Qnil;
}

// Mongory::CMatcher#condition
static VALUE ruby_mongory_matcher_condition(VALUE self) {
  ruby_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, ruby_mongory_matcher_t, &ruby_mongory_matcher_type, wrapper);
  return (VALUE)wrapper->condition->origin;
}

/**
 * Create a new memory pool
 */
static ruby_mongory_memory_pool_t *ruby_mongory_memory_pool_new() {
  ruby_mongory_memory_pool_t *pool = malloc(sizeof(ruby_mongory_memory_pool_t));
  mongory_memory_pool *base = mongory_memory_pool_new();
  memcpy(&pool->base, base, sizeof(mongory_memory_pool));
  free(base);

  return pool;
}

/**
 * Ruby GC management functions
 */
static void ruby_mongory_matcher_free(void *ptr) {
  ruby_mongory_matcher_t *wrapper = (ruby_mongory_matcher_t *)ptr;
  mongory_memory_pool *pool = wrapper->pool;
  mongory_memory_pool *scratch_pool = wrapper->scratch_pool;
  pool->free(pool);
  scratch_pool->free(scratch_pool);
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
static void ruby_mongory_matcher_mark(void *ptr) {
  ruby_mongory_matcher_t *wrapper = (ruby_mongory_matcher_t *)ptr;
  if (!wrapper) return;
  wrapper->mark_list->each(wrapper->mark_list, NULL, gc_mark_array_cb);
}

/**
 * Helper functions for Ruby/C conversion
 */

static mongory_value *ruby_to_mongory_value_primitive(mongory_memory_pool *pool, VALUE rb_value) {
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

  case T_STRING: {
    mg_value = mongory_value_wrap_s(pool, StringValueCStr(rb_value));
    break;
  }

  case T_SYMBOL: {
    mg_value = mongory_value_wrap_s(pool, (char *)rb_id2name(rb_sym2id(rb_value)));
    break;
  }

  case T_REGEXP: {
    mg_value = mongory_value_wrap_regex(pool, (void *)rb_value);
    break;
  }
  }
  return mg_value;
}
// Shallow conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
static mongory_value *ruby_to_mongory_value_shallow_rec(mongory_memory_pool *pool, VALUE rb_value, bool converted) {
  mongory_value *mg_value = ruby_to_mongory_value_primitive(pool, rb_value);
  if (mg_value) {
    mg_value->origin = rb_value;
    return mg_value;
  }

  switch (TYPE(rb_value)) {
  case T_ARRAY: {
    mg_value = ruby_mongory_array_wrap(pool, rb_value);
    break;
  }

  case T_HASH: {
    mg_value = ruby_mongory_table_wrap(pool, rb_value);
    break;
  }

  default:
    if (converted) {
      return mongory_value_wrap_u(pool, (void *)rb_value);
    } else {
      VALUE converted_value = rb_funcall(cMongoryDataConverter, rb_intern("convert"), 1, rb_value);
      return ruby_to_mongory_value_shallow_rec(pool, converted_value, true);
    }
  }
  mg_value->origin = rb_value;
  return mg_value;
}

// Shallow conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
mongory_value *ruby_to_mongory_value_shallow(mongory_memory_pool *pool, VALUE rb_value) {
  return ruby_to_mongory_value_shallow_rec(pool, rb_value, false);
}

static int hash_foreach_deep_convert_cb(VALUE key, VALUE val, VALUE ptr) {
  hash_conv_ctx *ctx = (hash_conv_ctx *)ptr;
  char *key_str;
  if (SYMBOL_P(key)) {
    key_str = (char *)rb_id2name(SYM2ID(key));
  } else {
    key_str = StringValueCStr(key);
  }
  mongory_value *cval = ruby_to_mongory_value_deep(ctx->pool, val);
  ctx->table->set(ctx->table, key_str, cval);
  return ST_CONTINUE;
}

mongory_value *ruby_to_mongory_value_deep(mongory_memory_pool *pool, VALUE rb_value) {
  ruby_mongory_memory_pool_t *rb_pool = (ruby_mongory_memory_pool_t *)pool;
  ruby_mongory_matcher_t *owner = rb_pool->owner;

  mongory_value *mg_value = ruby_to_mongory_value_primitive(pool, rb_value);
  if (mg_value) {
    mg_value->origin = rb_value;
    owner->mark_list->push(owner->mark_list, mg_value);
    return mg_value;
  }
  switch (TYPE(rb_value)) {
  case T_ARRAY: {
    mongory_array *array = mongory_array_new(pool);

    for (long i = 0; i < RARRAY_LEN(rb_value); i++) {
      array->push(array, ruby_to_mongory_value_deep(pool, RARRAY_AREF(rb_value, i)));
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
    rb_raise(eMongoryTypeError, "Unsupported Ruby type for conversion to mongory_value");
  }
  mg_value->origin = rb_value;
  owner->mark_list->push(owner->mark_list, mg_value);
  return mg_value;
}

mongory_value *ruby_mongory_table_get(mongory_table *self, char *key) {
  ruby_mongory_table_t *table = (ruby_mongory_table_t *)self;
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
  return ruby_to_mongory_value_shallow(table->base.pool, rb_value);
}

mongory_value *ruby_mongory_table_wrap(mongory_memory_pool *pool, VALUE rb_hash) {
  ruby_mongory_table_t *table = pool->alloc(pool->ctx, sizeof(ruby_mongory_table_t));
  ruby_mongory_memory_pool_t *rb_pool = (ruby_mongory_memory_pool_t *)pool;
  table->base.pool = pool;
  table->base.get = ruby_mongory_table_get;
  table->rb_hash = rb_hash;
  table->base.count = RHASH_SIZE(rb_hash);
  table->owner = rb_pool->owner;
  return mongory_value_wrap_t(pool, &table->base);
}

static mongory_value *ruby_mongory_array_get(mongory_array *self, size_t index) {
  ruby_mongory_array_t *array = (ruby_mongory_array_t *)self;
  VALUE rb_array = array->rb_array;
  if (index >= (size_t)RARRAY_LEN(rb_array)) {
    return NULL;
  }
  VALUE rb_value = rb_ary_entry(rb_array, index);
  return ruby_to_mongory_value_shallow(array->base.pool, rb_value);
}

static bool ruby_mongory_array_each(mongory_array *self, void *acc, mongory_array_callback_func func) {
  ruby_mongory_array_t *array = (ruby_mongory_array_t *)self;
  VALUE rb_array = array->rb_array;
  for (long i = 0; i < RARRAY_LEN(rb_array); i++) {
    VALUE rb_value = rb_ary_entry(rb_array, i);
    mongory_value *cval = ruby_to_mongory_value_shallow(array->base.pool, rb_value);
    if (!func(cval, acc)) {
      return false;
    }
  }
  return true;
}

mongory_value *ruby_mongory_array_wrap(mongory_memory_pool *pool, VALUE rb_array) {
  ruby_mongory_array_t *array = pool->alloc(pool->ctx, sizeof(ruby_mongory_array_t));
  ruby_mongory_memory_pool_t *rb_pool = (ruby_mongory_memory_pool_t *)pool;
  array->base.pool = pool;
  array->base.get = ruby_mongory_array_get;
  array->base.each = ruby_mongory_array_each;
  array->rb_array = rb_array;
  array->base.count = RARRAY_LEN(rb_array);
  array->owner = rb_pool->owner;
  return mongory_value_wrap_a(pool, &array->base);
}

// Convert mongory_value to Ruby value
void *mongory_value_to_ruby(mongory_memory_pool *pool, mongory_value *value) {
  (void)pool;
  if (!value)
    return NULL;
  return value->origin;
}

// ===== Cache helper implementations =====
static VALUE cache_fetch_string(ruby_mongory_matcher_t *owner, const char *key) {
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

static inline VALUE char_key_to_symbol(const char *key, rb_encoding *enc) {
  ID id = rb_check_id_cstr(key, (long)strlen(key), enc);
  if (!id) id = rb_intern3(key, (long)strlen(key), enc);
  return ID2SYM(id);
}

static VALUE cache_fetch_symbol(ruby_mongory_matcher_t *owner, const char *key) {
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
static bool ruby_regex_match_adapter(mongory_memory_pool *pool, mongory_value *pattern, mongory_value *value) {
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

static char *ruby_regex_stringify_adapter(mongory_memory_pool *pool, mongory_value *pattern) {
  (void)pool;
  if (pattern->type != MONGORY_TYPE_REGEX) {
    return NULL;
  }
  VALUE rb_re = (VALUE)pattern->data.regex;
  VALUE rb_str = rb_funcall(rb_re, rb_intern("inspect"), 0);
  return StringValueCStr(rb_str);
}

static mongory_matcher_custom_context *ruby_custom_matcher_build(char *key, mongory_value *condition) {
  mongory_memory_pool *pool = condition->pool;
  ruby_mongory_memory_pool_t *rb_pool = (ruby_mongory_memory_pool_t *)pool;
  ruby_mongory_matcher_t *owner = rb_pool->owner;
  VALUE matcher_class = rb_funcall(cMongoryMatchers, rb_intern("lookup"), 1, cache_fetch_string(owner, key));
  if (matcher_class == Qnil) {
    return NULL;
  }
  VALUE matcher = rb_funcall(matcher_class, rb_intern("new"), 1, condition->origin);
  if (matcher == Qnil) {
    return NULL;
  }
  mongory_value *matcher_value = mongory_value_wrap_u(pool, NULL);
  matcher_value->origin = (void *)matcher;
  owner->mark_list->push(owner->mark_list, matcher_value);
  VALUE class_name = rb_funcall(matcher_class, rb_intern("name"), 0);
  mongory_matcher_custom_context *return_ctx = MG_POOL_ALLOC(pool, mongory_matcher_custom_context);
  if (return_ctx == NULL) {
    return NULL;
  }
  return_ctx->name = StringValueCStr(class_name);
  return_ctx->external_ref = (void *)matcher;
  return return_ctx;
}

static bool ruby_custom_matcher_match(void *ruby_matcher, mongory_value *value) {
  VALUE matcher = (VALUE)ruby_matcher;
  VALUE match_result = rb_funcall(matcher, rb_intern("match?"), 1, value->origin);
  return RTEST(match_result);
}

static bool ruby_custom_matcher_lookup(char *key) {
  VALUE matcher_class = rb_funcall(cMongoryMatchers, rb_intern("lookup"), 1, rb_str_new_cstr(key));
  return RTEST(matcher_class);
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
  cMongoryMatchers = rb_define_module_under(mMongory, "Matchers");
  // Mongory converters
  cMongoryDataConverter = rb_funcall(mMongory, rb_intern("data_converter"), 0);
  cMongoryConditionConverter = rb_funcall(mMongory, rb_intern("condition_converter"), 0);

  // Define error classes
  eMongoryError = rb_define_class_under(mMongory, "Error", rb_eStandardError);
  eMongoryTypeError = rb_define_class_under(mMongory, "TypeError", eMongoryError);

  // Define Matcher methods
  rb_define_singleton_method(cMongoryMatcher, "new", ruby_mongory_matcher_new, 1);
  rb_define_method(cMongoryMatcher, "match?", ruby_mongory_matcher_match, 1);
  rb_define_method(cMongoryMatcher, "explain", ruby_mongory_matcher_explain, 0);
  rb_define_method(cMongoryMatcher, "condition", ruby_mongory_matcher_condition, 0);
  // Set regex adapter to use Ruby's Regexp
  mongory_regex_func_set(ruby_regex_match_adapter);
  mongory_regex_stringify_func_set(ruby_regex_stringify_adapter);
  // Set value converter functions
  mongory_value_converter_deep_convert_set(ruby_to_mongory_value_deep);
  mongory_value_converter_shallow_convert_set(ruby_to_mongory_value_shallow);
  mongory_value_converter_recover_set(mongory_value_to_ruby);
  // Set custom matcher adapter
  mongory_custom_matcher_match_func_set(ruby_custom_matcher_match);
  mongory_custom_matcher_build_func_set(ruby_custom_matcher_build);
  mongory_custom_matcher_lookup_func_set(ruby_custom_matcher_lookup);
}
