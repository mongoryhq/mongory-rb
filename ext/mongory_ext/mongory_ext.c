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

// Error classes
static VALUE eMongoryError;
static VALUE eMongoryTypeError;

// Matcher wrapper structure
typedef struct {
  mongory_matcher *matcher;
  mongory_memory_pool *pool;
  mongory_table *string_map;
  mongory_table *symbol_map;
} ruby_mongory_matcher_t;

// Thread-local current matcher wrapper for callbacks
#if defined(__STDC_NO_THREADS__) || defined(_WIN32)
static __thread ruby_mongory_matcher_t *g_current_wrapper;
#else
static _Thread_local ruby_mongory_matcher_t *g_current_wrapper;
#endif

/**
 * Ruby GC management functions
 */

static void ruby_mongory_matcher_free(void *ptr) {
  ruby_mongory_matcher_t *wrapper = (ruby_mongory_matcher_t *)ptr;
  mongory_memory_pool *pool = wrapper->pool;
  pool->free(pool);
  xfree(wrapper);
}

static void ruby_mongory_matcher_mark(void *ptr);

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
 * Helper functions for Ruby/C conversion
 */

typedef struct {
  mongory_table *table;
  mongory_memory_pool *pool;
  mongory_value *(*convert_func)(mongory_memory_pool *pool, void *value);
} hash_conv_ctx;

static int hash_foreach_cb(VALUE key, VALUE val, VALUE ptr) {
  hash_conv_ctx *ctx = (hash_conv_ctx *)ptr;
  char *key_str;
  if (SYMBOL_P(key)) {
    key_str = (char *)rb_id2name(SYM2ID(key));
  } else {
    key_str = StringValueCStr(key);
  }
  mongory_value *cval = ctx->convert_func(ctx->pool, (void *)val);
  ctx->table->set(ctx->table, key_str, cval);
  return ST_CONTINUE;
}

mongory_value *ruby_mongory_table_wrap(VALUE rb_hash, mongory_memory_pool *pool);
mongory_value *ruby_mongory_array_wrap(VALUE rb_array, mongory_memory_pool *pool);

// Cache helpers forward declarations
static VALUE cache_fetch_string(ruby_mongory_matcher_t *owner, const char *key);
static VALUE cache_fetch_symbol(ruby_mongory_matcher_t *owner, const char *key);

static mongory_value *ruby_to_mongory_value_primitive(mongory_memory_pool *pool, VALUE rb_value) {
  mongory_value *mg_value = NULL;
  switch (TYPE(rb_value)) {
  case T_NIL:
    mg_value = mongory_value_wrap_n(pool, NULL);
    break;

  case T_TRUE:
  case T_FALSE:
    mg_value = mongory_value_wrap_b(pool, RTEST(rb_value));
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
  }
  return mg_value;
}

// Shallow conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
mongory_value *ruby_to_mongory_value_shallow(mongory_memory_pool *pool, VALUE rb_value) {
  mongory_value *mg_value = ruby_to_mongory_value_primitive(pool, rb_value);
  if (mg_value) {
    mg_value->origin = rb_value;
    return mg_value;
  }

  switch (TYPE(rb_value)) {
  case T_ARRAY: {
    mg_value = ruby_mongory_array_wrap(rb_value, pool);
    break;
  }

  case T_HASH: {
    mg_value = ruby_mongory_table_wrap(rb_value, pool);
    break;
  }

  default:
    rb_raise(eMongoryTypeError, "Unsupported Ruby type for conversion to mongory_value");
  }
  mg_value->origin = rb_value;
  return mg_value;
}

mongory_value *ruby_to_mongory_value_deep(mongory_memory_pool *pool, VALUE rb_value) {
  mongory_value *mg_value = ruby_to_mongory_value_primitive(pool, rb_value);
  if (mg_value) {
    mg_value->origin = rb_value;
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

    hash_conv_ctx ctx = {table, pool, ruby_to_mongory_value_deep};
    rb_hash_foreach(rb_value, hash_foreach_cb, (VALUE)&ctx);

    mg_value = mongory_value_wrap_t(pool, table);
    break;
  }

  default:
    rb_raise(eMongoryTypeError, "Unsupported Ruby type for conversion to mongory_value");
  }
  mg_value->origin = rb_value;
  return mg_value;
}

typedef struct ruby_mongory_table_t {
  mongory_table base;
  VALUE rb_hash;
} ruby_mongory_table_t;

mongory_value *ruby_mongory_table_get(mongory_table *self, char *key) {
  ruby_mongory_table_t *table = (ruby_mongory_table_t *)self;
  VALUE rb_hash = table->rb_hash;
  VALUE rb_value = Qundef;

  // Use cached Ruby String key if possible
  VALUE key_str = cache_fetch_string(g_current_wrapper, key);
  rb_value = rb_hash_lookup2(rb_hash, key_str, Qundef);

  if (rb_value == Qundef) {
    // Fallback to Symbol key, using cache
    VALUE key_sym = cache_fetch_symbol(g_current_wrapper, key);
    rb_value = rb_hash_lookup2(rb_hash, key_sym, Qnil);
  }
  return ruby_to_mongory_value_shallow(self->pool, rb_value);
}

mongory_value *ruby_mongory_table_wrap(VALUE rb_hash, mongory_memory_pool *pool) {
  ruby_mongory_table_t *table = pool->alloc(pool->ctx, sizeof(ruby_mongory_table_t));
  table->base.pool = pool;
  table->base.get = ruby_mongory_table_get;
  table->rb_hash = rb_hash;
  table->base.count = RHASH_SIZE(rb_hash);
  return mongory_value_wrap_t(pool, &table->base);
}

typedef struct ruby_mongory_array_t {
  mongory_array base;
  VALUE rb_array;
} ruby_mongory_array_t;

mongory_value *ruby_mongory_array_get(mongory_array *self, size_t index) {
  ruby_mongory_array_t *array = (ruby_mongory_array_t *)self;
  VALUE rb_array = array->rb_array;
  VALUE rb_value = rb_ary_entry(rb_array, index);
  return ruby_to_mongory_value_shallow(self->pool, rb_value);
}

mongory_value *ruby_mongory_array_wrap(VALUE rb_array, mongory_memory_pool *pool) {
  ruby_mongory_array_t *array = pool->alloc(pool->ctx, sizeof(ruby_mongory_array_t));
  array->base.pool = pool;
  array->base.get = ruby_mongory_array_get;
  array->rb_array = rb_array;
  array->base.count = RARRAY_LEN(rb_array);
  return mongory_value_wrap_a(pool, &array->base);
}

// Convert mongory_value to Ruby value
void *mongory_value_to_ruby(mongory_memory_pool *pool, mongory_value *value) {
  (void)pool;
  if (!value)
    return NULL;
  return value->origin;
}

/**
 * Ruby method implementations
 */

// Mongory::CMatcher.new(condition)
static VALUE ruby_mongory_matcher_new(VALUE class, VALUE condition) {
  mongory_memory_pool *matcher_pool = mongory_memory_pool_new();
  mongory_value *condition_value = ruby_to_mongory_value_deep(matcher_pool, condition);
  mongory_matcher *matcher = mongory_matcher_new(matcher_pool, condition_value);

  if (!matcher) {
    rb_raise(eMongoryError, "Failed to create matcher");
  }

  ruby_mongory_matcher_t *wrapper = ALLOC(ruby_mongory_matcher_t);
  wrapper->matcher = matcher;
  wrapper->pool = matcher_pool;
  wrapper->string_map = mongory_table_new(matcher_pool);
  wrapper->symbol_map = mongory_table_new(matcher_pool);

  return TypedData_Wrap_Struct(class, &ruby_mongory_matcher_type, wrapper);
}

// Mongory::CMatcher#match(data)
static VALUE ruby_mongory_matcher_match(VALUE self, VALUE data) {
  ruby_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, ruby_mongory_matcher_t, &ruby_mongory_matcher_type, wrapper);

  mongory_memory_pool *temp_pool = mongory_memory_pool_new();
  ruby_mongory_matcher_t *prev = g_current_wrapper;
  g_current_wrapper = wrapper;
  mongory_value *data_value = ruby_to_mongory_value_shallow(temp_pool, data);
  bool result = mongory_matcher_match(wrapper->matcher, data_value);
  g_current_wrapper = prev;

  temp_pool->free(temp_pool);
  return result ? Qtrue : Qfalse;
}

// Mongory::CMatcher#explain
static VALUE ruby_mongory_matcher_explain(VALUE self) {
  ruby_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, ruby_mongory_matcher_t, &ruby_mongory_matcher_type, wrapper);
  mongory_memory_pool *temp_pool = mongory_memory_pool_new();
  mongory_matcher_explain(wrapper->matcher, temp_pool);
  temp_pool->free(temp_pool);
  return Qnil;
}

// ===== Key cache helpers and GC marking =====
static bool gc_mark_table_cb(char *key, mongory_value *value, void *acc) {
  (void)key; (void)acc;
  if (value && value->origin) rb_gc_mark((VALUE)value->origin);
  return true;
}

static void ruby_mongory_matcher_mark_table(mongory_table *table) {
  if (table && table->each) {
    table->each(table, NULL, gc_mark_table_cb);
  }
}

static void ruby_mongory_matcher_mark(void *ptr) {
  ruby_mongory_matcher_t *wrapper = (ruby_mongory_matcher_t *)ptr;
  if (!wrapper) return;
  ruby_mongory_matcher_mark_table(wrapper->string_map);
  ruby_mongory_matcher_mark_table(wrapper->symbol_map);
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
  return sym;
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

  // Define error classes
  eMongoryError = rb_define_class_under(mMongory, "Error", rb_eStandardError);
  eMongoryTypeError = rb_define_class_under(mMongory, "TypeError", eMongoryError);

  // Define Matcher methods
  rb_define_singleton_method(cMongoryMatcher, "new", ruby_mongory_matcher_new, 1);
  rb_define_method(cMongoryMatcher, "match", ruby_mongory_matcher_match, 1);
  rb_define_method(cMongoryMatcher, "explain", ruby_mongory_matcher_explain, 0);
  // Set value converter functions
  mongory_value_converter_deep_convert_set(ruby_to_mongory_value_deep);
  mongory_value_converter_shallow_convert_set(ruby_to_mongory_value_shallow);
  mongory_value_converter_recover_set(mongory_value_to_ruby);
}
