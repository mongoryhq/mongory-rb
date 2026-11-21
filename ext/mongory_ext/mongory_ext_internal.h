#ifndef MONGORY_EXT_INTERNAL_H
#define MONGORY_EXT_INTERNAL_H

/**
 * @file mongory_ext_internal.h
 * @brief Shared types, globals, and internal prototypes across mongory_ext C translation units.
 */

#include "mongory-core.h"
#include <ruby.h>
#include <ruby/encoding.h>

// Shared Ruby module, class, error, and converter references initialized in Init_mongory_ext
extern VALUE rb_mongory_m_mongory;
extern VALUE rb_mongory_m_matchers;
extern VALUE rb_mongory_c_matcher;
extern VALUE rb_mongory_c_matcher_context;
extern VALUE rb_mongory_e_error;
extern VALUE rb_mongory_e_type_error;
extern VALUE rb_mongory_data_converter;
extern VALUE rb_mongory_condition_converter;

typedef struct rb_mongory_memory_pool_t rb_mongory_memory_pool_t;

// Matcher wrapper structure
typedef struct rb_mongory_matcher_t {
  mongory_matcher *matcher;
  mongory_value *condition;
  mongory_memory_pool *pool;
  rb_mongory_memory_pool_t *scratch_free_list;
  mongory_memory_pool *trace_pool;
  mongory_table *string_map;
  mongory_table *symbol_map;
  mongory_array *mark_list;
  VALUE ctx;
} rb_mongory_matcher_t;

struct rb_mongory_memory_pool_t {
  mongory_memory_pool base;
  rb_mongory_matcher_t *owner;
  rb_mongory_memory_pool_t *next_scratch;
};

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

// Pool & error helpers (mongory_ext.c)
rb_mongory_memory_pool_t *rb_mongory_memory_pool_new(void);
bool rb_mongory_error_handling(mongory_memory_pool *pool, const char *error_message);

// Matcher registration (rb_mongory_matcher.c)
void rb_mongory_init_matcher(void);

// Value conversion, lazy wrappers, and key caches (rb_mongory_value.c)
mongory_value *rb_to_mongory_value_deep(mongory_memory_pool *pool, VALUE rb_value);
mongory_value *rb_to_mongory_value_shallow(mongory_memory_pool *pool, VALUE rb_value);
mongory_value *rb_mongory_table_wrap(mongory_memory_pool *pool, VALUE rb_hash);
mongory_value *rb_mongory_array_wrap(mongory_memory_pool *pool, VALUE rb_array);
void *mongory_value_to_ruby(mongory_memory_pool *pool, mongory_value *value);
VALUE rb_mongory_cache_fetch_string(rb_mongory_matcher_t *owner, const char *key);
VALUE rb_mongory_cache_fetch_symbol(rb_mongory_matcher_t *owner, const char *key);

// Core regex & custom matcher adapters (rb_mongory_adapters.c)
void rb_mongory_register_adapters(void);

#endif // MONGORY_EXT_INTERNAL_H
