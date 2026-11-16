/**
 * @file rb_mongory_cmatcher.c
 * @brief Mongory::CMatcher Ruby class lifecycle, matching, and trace methods.
 */
#include "mongory_ext_internal.h"
#include <stdio.h>
#include <string.h>

static void rb_mongory_matcher_mark(void *ptr);
static void rb_mongory_matcher_free(void *ptr);
static void rb_mongory_matcher_parse_argv(rb_mongory_matcher_t *self, int argc, VALUE *argv);

static const rb_data_type_t rb_mongory_matcher_type = {
  .wrap_struct_name = "mongory_matcher",
  .function = {
    .dmark = rb_mongory_matcher_mark,
    .dfree = rb_mongory_matcher_free,
    .dsize = NULL,
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

static void rb_mongory_matcher_release_pools(rb_mongory_matcher_t *wrapper) {
  if (wrapper->pool) {
    wrapper->pool->free(wrapper->pool);
    wrapper->pool = NULL;
  }
  if (wrapper->scratch_pool) {
    wrapper->scratch_pool->free(wrapper->scratch_pool);
    wrapper->scratch_pool = NULL;
  }
  if (wrapper->trace_pool) {
    wrapper->trace_pool->free(wrapper->trace_pool);
    wrapper->trace_pool = NULL;
  }
  wrapper->matcher = NULL;
  wrapper->condition = NULL;
  wrapper->string_map = NULL;
  wrapper->symbol_map = NULL;
  wrapper->mark_list = NULL;
  wrapper->ctx = 0;
}

static rb_mongory_matcher_t *get_initialized_matcher(VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  if (!wrapper || !wrapper->matcher || !wrapper->condition || !wrapper->pool || !wrapper->scratch_pool) {
    rb_raise(rb_mongory_e_error, "uninitialized %s", rb_obj_classname(self));
  }
  return wrapper;
}

static void rb_mongory_matcher_free(void *ptr) {
  rb_mongory_matcher_t *wrapper = (rb_mongory_matcher_t *)ptr;
  if (!wrapper) return;
  rb_mongory_matcher_release_pools(wrapper);
  xfree(wrapper);
}

static bool gc_mark_array_cb(mongory_value *value, void *acc) {
  (void)acc;
  if (value && value->origin) rb_gc_mark((VALUE)value->origin);
  return true;
}

static void rb_mongory_matcher_mark(void *ptr) {
  rb_mongory_matcher_t *self = (rb_mongory_matcher_t *)ptr;
  if (!self) return;
  if (self->ctx) rb_gc_mark(self->ctx);
  if (self->mark_list) {
    self->mark_list->each(self->mark_list, NULL, gc_mark_array_cb);
  }
}

static VALUE rb_mongory_matcher_alloc(VALUE klass) {
  rb_mongory_matcher_t *wrapper;
  VALUE obj = TypedData_Make_Struct(klass, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  memset(wrapper, 0, sizeof(rb_mongory_matcher_t));
  return obj;
}

// Mongory::CMatcher#initialize(condition, context: ...)
static VALUE rb_mongory_matcher_initialize(int argc, VALUE *argv, VALUE self) {
  rb_mongory_matcher_t *wrapper;
  TypedData_Get_Struct(self, rb_mongory_matcher_t, &rb_mongory_matcher_type, wrapper);
  rb_mongory_matcher_release_pools(wrapper);

  rb_mongory_memory_pool_t *matcher_pool = rb_mongory_memory_pool_new();
  mongory_memory_pool *matcher_pool_base = &matcher_pool->base;
  rb_mongory_memory_pool_t *scratch_pool = rb_mongory_memory_pool_new();
  mongory_memory_pool *scratch_pool_base = &scratch_pool->base;
  wrapper->pool = matcher_pool_base;
  wrapper->scratch_pool = scratch_pool_base;
  wrapper->string_map = mongory_table_new(matcher_pool_base);
  wrapper->symbol_map = mongory_table_new(matcher_pool_base);
  wrapper->mark_list = mongory_array_new(matcher_pool_base);
  matcher_pool->owner = wrapper;
  scratch_pool->owner = wrapper;
  rb_mongory_matcher_parse_argv(wrapper, argc, argv);

  mongory_matcher *matcher = mongory_matcher_new(matcher_pool_base, wrapper->condition, wrapper->ctx);
  if (matcher_pool_base->error || !matcher) {
    char err_msg[256];
    snprintf(err_msg, sizeof(err_msg), "%s",
             (matcher_pool_base->error && matcher_pool_base->error->message)
                 ? matcher_pool_base->error->message
                 : "Unknown error");
    rb_mongory_matcher_release_pools(wrapper);
    rb_raise(rb_mongory_e_type_error, "Failed to create matcher: %s", err_msg);
  }

  wrapper->matcher = matcher;
  return self;
}

// Disallow dup/clone so C memory pools are never shared across instances
static VALUE rb_mongory_matcher_initialize_copy(VALUE self, VALUE orig) {
  (void)orig;
  rb_raise(rb_eTypeError, "can't copy %s", rb_obj_classname(self));
}

static void rb_mongory_matcher_parse_argv(rb_mongory_matcher_t *self, int argc, VALUE *argv) {
  VALUE condition, kw_hash;
  if (argc == 1) {
    // In Ruby 3.0+, a single bare hash like `CMatcher.new(name: 'John')` is marked
    // as keywords, which would fail `rb_scan_args(..., "1:", ...)` with 0 positional args.
    rb_scan_args(argc, argv, "1", &condition);
    kw_hash = Qnil;
  } else {
    rb_scan_args(argc, argv, "1:", &condition, &kw_hash);
  }
  const ID ctx_id[1] = { rb_intern("context") };
  VALUE kw_vals[1] = { Qundef };
  if (kw_hash != Qnil) {
    rb_get_kwargs(kw_hash, ctx_id, 0, 1, kw_vals);
  }
  if (kw_vals[0] != Qundef) {
    self->ctx = kw_vals[0];
  } else {
    self->ctx = rb_funcall(rb_mongory_c_matcher_context, rb_intern("new"), 0);
  }
  VALUE converted_condition = rb_funcall(rb_mongory_condition_converter, rb_intern("convert"), 1, condition);
  self->condition = rb_to_mongory_value_deep(self->pool, converted_condition);
  self->mark_list->push(self->mark_list, self->condition);
  mongory_value *store_ctx = mongory_value_wrap_u(self->pool, (void *)self->ctx);
  store_ctx->origin = (void *)self->ctx;
  self->mark_list->push(self->mark_list, store_ctx);
}

// Mongory::CMatcher#match?(data)
static VALUE rb_mongory_matcher_match(VALUE self, VALUE data) {
  rb_mongory_matcher_t *self_wrapper = get_initialized_matcher(self);
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
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);
  mongory_matcher_explain(wrapper->matcher, wrapper->scratch_pool);
  if (rb_mongory_error_handling(wrapper->scratch_pool, "Explain failed")) {
    return Qnil;
  }
  wrapper->scratch_pool->reset(wrapper->scratch_pool);
  return Qnil;
}

// Mongory::CMatcher#trace(data)
static VALUE rb_mongory_matcher_trace(VALUE self, VALUE data) {
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);
  rb_mongory_memory_pool_t *trace_pool = rb_mongory_memory_pool_new();
  trace_pool->owner = wrapper;
  mongory_memory_pool *trace_pool_base = &trace_pool->base;
  mongory_value *data_value = rb_to_mongory_value_shallow(trace_pool_base, data);

  if (trace_pool_base->error) {
    char err_msg[256];
    snprintf(err_msg, sizeof(err_msg), "%s",
             trace_pool_base->error->message ? trace_pool_base->error->message : "Unknown error");
    trace_pool_base->free(trace_pool_base);
    rb_raise(rb_mongory_e_type_error, "Trace failed: %s", err_msg);
  }

  bool matched = mongory_matcher_trace(wrapper->matcher, data_value);
  trace_pool_base->free(trace_pool_base);

  return matched ? Qtrue : Qfalse;
}

// Mongory::CMatcher#enable_trace
static VALUE rb_mongory_matcher_enable_trace(VALUE self) {
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);
  if (wrapper->trace_pool) {
    wrapper->trace_pool->free(wrapper->trace_pool);
    wrapper->trace_pool = NULL;
  }
  rb_mongory_memory_pool_t *trace_pool = rb_mongory_memory_pool_new();
  trace_pool->owner = wrapper;
  mongory_memory_pool *trace_pool_base = &trace_pool->base;
  mongory_matcher_enable_trace(wrapper->matcher, trace_pool_base);

  if (trace_pool_base->error) {
    char err_msg[256];
    snprintf(err_msg, sizeof(err_msg), "%s",
             trace_pool_base->error->message ? trace_pool_base->error->message : "Unknown error");
    trace_pool_base->free(trace_pool_base);
    rb_raise(rb_mongory_e_type_error, "Enable trace failed: %s", err_msg);
  }
  wrapper->trace_pool = trace_pool_base;

  return Qnil;
}

// Mongory::CMatcher#disable_trace
static VALUE rb_mongory_matcher_disable_trace(VALUE self) {
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);
  mongory_memory_pool *trace_pool = wrapper->trace_pool;
  mongory_matcher_disable_trace(wrapper->matcher);
  if (trace_pool) {
    wrapper->trace_pool = NULL;
    if (trace_pool->error) {
      char err_msg[256];
      snprintf(err_msg, sizeof(err_msg), "%s",
               trace_pool->error->message ? trace_pool->error->message : "Unknown error");
      trace_pool->free(trace_pool);
      rb_raise(rb_mongory_e_type_error, "Disable trace failed: %s", err_msg);
    }
    trace_pool->free(trace_pool);
  }

  return Qnil;
}

// Mongory::CMatcher#print_trace
static VALUE rb_mongory_matcher_print_trace(VALUE self) {
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);
  if (!wrapper->trace_pool) {
    return Qnil;
  }
  mongory_matcher_print_trace(wrapper->matcher);
  rb_mongory_error_handling(wrapper->trace_pool, "Print trace failed");

  return Qnil;
}

// Mongory::CMatcher#condition
static VALUE rb_mongory_matcher_condition(VALUE self) {
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);

  return (VALUE)wrapper->condition->origin;
}

// Mongory::CMatcher#context
static VALUE rb_mongory_matcher_context(VALUE self) {
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);

  return wrapper->ctx ? wrapper->ctx : Qnil;
}

// Mongory::CMatcher.trace_result_colorful=(colorful)
static VALUE rb_mongory_matcher_trace_result_colorful(VALUE self, VALUE colorful) {
  (void)self;
  mongory_matcher_trace_result_colorful_set(RTEST(colorful));

  return Qnil;
}

void rb_mongory_init_cmatcher(void) {
  rb_mongory_c_matcher = rb_define_class_under(rb_mongory_m_mongory, "CMatcher", rb_cObject);
  rb_define_alloc_func(rb_mongory_c_matcher, rb_mongory_matcher_alloc);

  rb_define_method(rb_mongory_c_matcher, "initialize", rb_mongory_matcher_initialize, -1);
  rb_define_method(rb_mongory_c_matcher, "initialize_copy", rb_mongory_matcher_initialize_copy, 1);
  rb_define_singleton_method(rb_mongory_c_matcher, "trace_result_colorful=", rb_mongory_matcher_trace_result_colorful, 1);
  rb_define_method(rb_mongory_c_matcher, "match?", rb_mongory_matcher_match, 1);
  rb_define_method(rb_mongory_c_matcher, "explain", rb_mongory_matcher_explain, 0);
  rb_define_method(rb_mongory_c_matcher, "condition", rb_mongory_matcher_condition, 0);
  rb_define_method(rb_mongory_c_matcher, "context", rb_mongory_matcher_context, 0);
  rb_define_method(rb_mongory_c_matcher, "trace", rb_mongory_matcher_trace, 1);
  rb_define_method(rb_mongory_c_matcher, "enable_trace", rb_mongory_matcher_enable_trace, 0);
  rb_define_method(rb_mongory_c_matcher, "disable_trace", rb_mongory_matcher_disable_trace, 0);
  rb_define_method(rb_mongory_c_matcher, "print_trace", rb_mongory_matcher_print_trace, 0);
}
