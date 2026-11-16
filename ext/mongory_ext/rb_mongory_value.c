/**
 * @file rb_mongory_value.c
 * @brief Ruby <-> mongory_value conversion, lazy wrappers, and key caches.
 */
#include "mongory_ext_internal.h"
#include <string.h>

typedef struct {
  mongory_table *table;
  mongory_memory_pool *pool;
} hash_conv_ctx;

static char *rb_mongory_value_to_cstr(mongory_value *value, mongory_memory_pool *pool) {
  (void)pool;
  VALUE rb_value = (VALUE)value->origin;
  VALUE rb_str = rb_funcall(rb_value, rb_intern("inspect"), 0);
  return StringValueCStr(rb_str);
}

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

static mongory_value *rb_to_mongory_value_shallow_rec(mongory_memory_pool *pool, VALUE rb_value, bool converted) {
  mongory_value *mg_value = rb_to_mongory_value_primitive(pool, rb_value);
  if (mg_value) {
    mg_value->origin = rb_value;
    return mg_value;
  }

  switch (TYPE(rb_value)) {
  case T_ARRAY:
    mg_value = rb_mongory_array_wrap(pool, rb_value);
    break;

  case T_HASH:
    mg_value = rb_mongory_table_wrap(pool, rb_value);
    break;

  default:
    if (converted) {
      mg_value = mongory_value_wrap_u(pool, (void *)rb_value);
      break;
    } else {
      VALUE converted_value = rb_funcall(rb_mongory_data_converter, rb_intern("convert"), 1, rb_value);
      return rb_to_mongory_value_shallow_rec(pool, converted_value, true);
    }
  }
  mg_value->origin = rb_value;
  return mg_value;
}

mongory_value *rb_to_mongory_value_shallow(mongory_memory_pool *pool, VALUE rb_value) {
  return rb_to_mongory_value_shallow_rec(pool, rb_value, false);
}

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
    if (!RB_TYPE_P(key, T_STRING)) {
      key = rb_obj_as_string(key);
    }
    key_str = StringValueCStr(key);
    store_map = owner->string_map;
  }
  mongory_value *store = mongory_value_wrap_u(ctx->pool, NULL);
  store->origin = (void *)key;
  store_map->set(store_map, key_str, store);
  owner->mark_list->push(owner->mark_list, store);
  mongory_value *cval = rb_to_mongory_value_deep(ctx->pool, val);
  ctx->table->set(ctx->table, key_str, cval);
  return ST_CONTINUE;
}

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
      VALUE converted_value = rb_funcall(rb_mongory_data_converter, rb_intern("convert"), 1, rb_value);
      mg_value = rb_to_mongory_value_deep_rec(pool, converted_value, true);
      break;
    }
  }
  mg_value->origin = rb_value;
  return mg_value;
}

mongory_value *rb_to_mongory_value_deep(mongory_memory_pool *pool, VALUE rb_value) {
  return rb_to_mongory_value_deep_rec(pool, rb_value, false);
}

static mongory_value *rb_mongory_table_get(mongory_table *self, char *key) {
  rb_mongory_table_t *table = (rb_mongory_table_t *)self;
  VALUE rb_hash = table->rb_hash;
  VALUE rb_value = Qundef;

  VALUE key_str = rb_mongory_cache_fetch_string(table->owner, key);
  rb_value = rb_hash_lookup2(rb_hash, key_str, Qundef);

  if (rb_value == Qundef) {
    VALUE key_sym = rb_mongory_cache_fetch_symbol(table->owner, key);
    rb_value = rb_hash_lookup2(rb_hash, key_sym, Qundef);
  }

  if (rb_value == Qundef) {
    return NULL;
  }
  return rb_to_mongory_value_shallow(table->base.pool, rb_value);
}

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

static mongory_value *rb_mongory_array_get(mongory_array *self, size_t index) {
  rb_mongory_array_t *array = (rb_mongory_array_t *)self;
  VALUE rb_array = array->rb_array;
  if (index >= (size_t)RARRAY_LEN(rb_array)) {
    return NULL;
  }
  VALUE rb_value = rb_ary_entry(rb_array, index);
  return rb_to_mongory_value_shallow(self->pool, rb_value);
}

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

void *mongory_value_to_ruby(mongory_memory_pool *pool, mongory_value *value) {
  (void)pool;
  if (!value)
    return NULL;
  return value->origin;
}

VALUE rb_mongory_cache_fetch_string(rb_mongory_matcher_t *owner, const char *key) {
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

VALUE rb_mongory_cache_fetch_symbol(rb_mongory_matcher_t *owner, const char *key) {
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
