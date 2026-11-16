/**
 * @file mongory_ext.c
 * @brief Extension entry point and shared pool/error helpers for mongory-rb.
 */
#include "mongory_ext_internal.h"
#include <stdlib.h>
#include <string.h>

VALUE rb_mongory_m_mongory;
VALUE rb_mongory_m_matchers;
VALUE rb_mongory_c_matcher;
VALUE rb_mongory_c_matcher_context;
VALUE rb_mongory_e_error;
VALUE rb_mongory_e_type_error;
VALUE rb_mongory_data_converter;
VALUE rb_mongory_condition_converter;

rb_mongory_memory_pool_t *rb_mongory_memory_pool_new(void) {
  rb_mongory_memory_pool_t *pool = malloc(sizeof(rb_mongory_memory_pool_t));
  mongory_memory_pool *base = mongory_memory_pool_new();
  memcpy(&pool->base, base, sizeof(mongory_memory_pool));
  pool->owner = NULL;
  free(base);

  return pool;
}

bool rb_mongory_error_handling(mongory_memory_pool *pool, const char *error_message) {
  if (pool->error) {
    const char *msg = pool->error->message;
    pool->error = NULL;
    rb_raise(rb_mongory_e_type_error, "%s: %s", error_message, msg);
  }
  return false;
}

void Init_mongory_ext(void) {
  // Initialize mongory core
  mongory_init();

  // Define modules and classes
  rb_mongory_m_mongory = rb_define_module("Mongory");
  rb_mongory_m_matchers = rb_define_module_under(rb_mongory_m_mongory, "Matchers");
  VALUE mMongoryUtils = rb_define_module_under(rb_mongory_m_mongory, "Utils");
  rb_mongory_c_matcher_context = rb_define_class_under(mMongoryUtils, "Context", rb_cObject);

  // Mongory converters
  rb_mongory_data_converter = rb_funcall(rb_mongory_m_mongory, rb_intern("data_converter"), 0);
  rb_mongory_condition_converter = rb_funcall(rb_mongory_m_mongory, rb_intern("condition_converter"), 0);

  // Define error classes
  rb_mongory_e_error = rb_define_class_under(rb_mongory_m_mongory, "Error", rb_eStandardError);
  rb_mongory_e_type_error = rb_define_class_under(rb_mongory_m_mongory, "TypeError", rb_mongory_e_error);

  // Register CMatcher class, methods, and core bridges
  rb_mongory_init_cmatcher();
  rb_mongory_register_adapters();
}
