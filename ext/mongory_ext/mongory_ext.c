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
} ruby_mongory_matcher_t;

/**
 * Ruby GC management functions
 */

static void ruby_mongory_matcher_free(void *ptr) {
  ruby_mongory_matcher_t *wrapper = (ruby_mongory_matcher_t *)ptr;
  mongory_memory_pool *pool = wrapper->pool;
  pool->free(pool);
  xfree(wrapper);
}

static const rb_data_type_t ruby_mongory_matcher_type = {
  .wrap_struct_name = "mongory_matcher",
  .function = {
    .dmark = NULL,
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

// Deep conversion: Convert Ruby value to mongory_value (fully materialize arrays/tables)
static mongory_value *ruby_to_mongory_value(VALUE rb_value, mongory_memory_pool *pool, mongory_value *(*convert_func)(mongory_memory_pool *pool, void *value)) {
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

  case T_ARRAY: {
    mongory_array *array = mongory_array_new(pool);
    long len = RARRAY_LEN(rb_value);

    for (long i = 0; i < len; i++) {
      VALUE element = RARRAY_AREF(rb_value, i);
      array->push(array, convert_func(pool, element));
    }
    mg_value = mongory_value_wrap_a(pool, array);
    break;
  }

  case T_HASH: {
    mongory_table *table = mongory_table_new(pool);

    hash_conv_ctx ctx = {table, pool, convert_func};
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

// Shallow conversion: only materialize scalars; arrays/hashes remain as POINTER to Ruby VALUE
static mongory_value *ruby_to_mongory_value_shallow(mongory_memory_pool *pool, void *value) {
  return ruby_to_mongory_value(value, pool, mongory_value_wrap_ptr);
}
static mongory_value *ruby_to_mongory_value_deep(mongory_memory_pool *pool, void *value) {
  return ruby_to_mongory_value(value, pool, ruby_to_mongory_value_deep);
}

// Convert mongory_value to Ruby value
static void *mongory_value_to_ruby(mongory_memory_pool *pool, mongory_value *value) {
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

  return TypedData_Wrap_Struct(class, &ruby_mongory_matcher_type, wrapper);
}

// Mongory::CMatcher#match(data)
static VALUE ruby_mongory_matcher_match(VALUE self, VALUE data) {
  ruby_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, ruby_mongory_matcher_t, &ruby_mongory_matcher_type, wrapper);

  mongory_memory_pool *temp_pool = mongory_memory_pool_new();
  mongory_value *data_value = ruby_to_mongory_value_shallow(temp_pool, data);
  bool result = mongory_matcher_match(wrapper->matcher, data_value);

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
