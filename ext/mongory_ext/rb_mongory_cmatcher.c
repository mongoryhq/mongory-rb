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
  while (wrapper->scratch_free_list) {
    rb_mongory_memory_pool_t *scratch = wrapper->scratch_free_list;
    wrapper->scratch_free_list = scratch->next_scratch;
    scratch->next_scratch = NULL;
    scratch->base.free(&scratch->base);
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
  if (!wrapper || !wrapper->matcher || !wrapper->condition || !wrapper->pool) {
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
  rb_mongory_memory_pool_t *scratch_pool = rb_mongory_memory_pool_new();
  if (!matcher_pool || !scratch_pool) {
    if (matcher_pool) matcher_pool->base.free(&matcher_pool->base);
    if (scratch_pool) scratch_pool->base.free(&scratch_pool->base);
    rb_raise(rb_mongory_e_error, "Failed to allocate matcher memory pools");
  }
  mongory_memory_pool *matcher_pool_base = &matcher_pool->base;
  wrapper->pool = matcher_pool_base;
  wrapper->scratch_free_list = scratch_pool;
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

typedef struct {
  rb_mongory_matcher_t *wrapper;
  mongory_memory_pool *owner_pool;
  rb_mongory_memory_pool_t *scratch;
} rb_mongory_scratch_lease_t;

typedef struct {
  rb_mongory_matcher_t *wrapper;
  mongory_memory_pool *scratch_pool;
  VALUE data;
} rb_mongory_match_call_t;

typedef struct {
  rb_mongory_matcher_t *wrapper;
  mongory_memory_pool *scratch_pool;
} rb_mongory_explain_call_t;

// Pops an idle scratch pool from wrapper->scratch_free_list, or allocates a new
// reusable pool when re-entered concurrently; release resets and pushes it back.
static rb_mongory_scratch_lease_t rb_mongory_scratch_acquire(rb_mongory_matcher_t *wrapper) {
  rb_mongory_memory_pool_t *scratch = wrapper->scratch_free_list;
  if (scratch) {
    wrapper->scratch_free_list = scratch->next_scratch;
    scratch->next_scratch = NULL;
    scratch->base.error = NULL;
  } else {
    scratch = rb_mongory_memory_pool_new();
    if (!scratch) {
      rb_raise(rb_mongory_e_error, "Failed to allocate scratch pool");
    }
    scratch->owner = wrapper;
  }
  rb_mongory_scratch_lease_t lease = {
    .wrapper = wrapper,
    .owner_pool = wrapper->pool,
    .scratch = scratch,
  };
  return lease;
}

static VALUE rb_mongory_scratch_release(VALUE arg) {
  rb_mongory_scratch_lease_t *lease = (rb_mongory_scratch_lease_t *)arg;
  rb_mongory_memory_pool_t *scratch = lease->scratch;
  if (!scratch) {
    return Qnil;
  }
  lease->scratch = NULL;
  if (lease->wrapper && lease->wrapper->pool == lease->owner_pool) {
    scratch->base.error = NULL;
    scratch->base.reset(&scratch->base);
    scratch->next_scratch = lease->wrapper->scratch_free_list;
    lease->wrapper->scratch_free_list = scratch;
  } else {
    scratch->base.free(&scratch->base);
  }
  return Qnil;
}

static VALUE rb_mongory_matcher_match_body(VALUE arg) {
  rb_mongory_match_call_t *call = (rb_mongory_match_call_t *)arg;
  rb_mongory_matcher_t *self_wrapper = call->wrapper;
  mongory_matcher *matcher = self_wrapper->matcher;
  mongory_memory_pool *scratch_pool = call->scratch_pool;
  mongory_memory_pool *trace_pool = self_wrapper->trace_pool;
  mongory_value *data_value = rb_to_mongory_value_shallow(scratch_pool, call->data);

  if (rb_mongory_error_handling(scratch_pool, "Match failed")) {
    return Qnil;
  }

  bool result = mongory_matcher_match(matcher, data_value);

  if (trace_pool) {
    mongory_matcher_print_trace(matcher);
    trace_pool->reset(trace_pool);
    mongory_matcher_enable_trace(matcher, trace_pool);
  }

  return result ? Qtrue : Qfalse;
}

// Mongory::CMatcher#match?(data)
static VALUE rb_mongory_matcher_match(VALUE self, VALUE data) {
  rb_mongory_matcher_t *self_wrapper = get_initialized_matcher(self);
  rb_mongory_scratch_lease_t lease = rb_mongory_scratch_acquire(self_wrapper);
  rb_mongory_match_call_t call = {
    .wrapper = self_wrapper,
    .scratch_pool = &lease.scratch->base,
    .data = data,
  };
  VALUE result = rb_ensure(rb_mongory_matcher_match_body, (VALUE)&call, rb_mongory_scratch_release, (VALUE)&lease);
  RB_GC_GUARD(self);
  return result;
}

static VALUE rb_mongory_value_to_rb(mongory_value *val);

static bool rb_mongory_table_entry_to_rb_hash(char *key, mongory_value *val, void *acc) {
  VALUE hash = (VALUE)acc;
  VALUE rb_key = rb_utf8_str_new_cstr(key ? key : "");
  VALUE rb_val = rb_mongory_value_to_rb(val);
  rb_hash_aset(hash, rb_key, rb_val);
  return true;
}

static VALUE rb_mongory_value_to_rb(mongory_value *val) {
  if (!val) {
    return Qnil;
  }
  if (val->origin != NULL) {
    return (VALUE)val->origin;
  }
  switch (val->type) {
    case MONGORY_TYPE_NULL:
      return Qnil;
    case MONGORY_TYPE_BOOL:
      return val->data.b ? Qtrue : Qfalse;
    case MONGORY_TYPE_INT:
      return LL2NUM(val->data.i);
    case MONGORY_TYPE_DOUBLE:
      return DBL2NUM(val->data.d);
    case MONGORY_TYPE_STRING:
      return rb_utf8_str_new_cstr(val->data.s ? val->data.s : "");
    case MONGORY_TYPE_ARRAY: {
      mongory_array *arr = val->data.a;
      size_t count = arr ? arr->count : 0;
      VALUE rb_arr = rb_ary_new_capa((long)count);
      for (size_t i = 0; i < count; i++) {
        rb_ary_push(rb_arr, rb_mongory_value_to_rb(arr->get(arr, i)));
      }
      return rb_arr;
    }
    case MONGORY_TYPE_TABLE: {
      VALUE rb_hash = rb_hash_new();
      if (val->data.t && val->data.t->each) {
        val->data.t->each(val->data.t, (void *)rb_hash, rb_mongory_table_entry_to_rb_hash);
      }
      return rb_hash;
    }
    default:
      return Qnil;
  }
}

static VALUE rb_mongory_tree_node_to_rb(mongory_value *node_val) {
  if (!node_val || node_val->type != MONGORY_TYPE_TABLE || !node_val->data.t) {
    return Qnil;
  }
  mongory_table *node = node_val->data.t;
  VALUE hash = rb_hash_new();

  mongory_value *name_val = node->get(node, "name");
  if (name_val && name_val->type == MONGORY_TYPE_STRING) {
    rb_hash_aset(hash, ID2SYM(rb_intern("name")), rb_utf8_str_new_cstr(name_val->data.s ? name_val->data.s : ""));
  }

  mongory_value *cond_val = node->get(node, "condition");
  rb_hash_aset(hash, ID2SYM(rb_intern("condition")), rb_mongory_value_to_rb(cond_val));

  mongory_value *priority_val = node->get(node, "priority");
  if (priority_val && priority_val->type == MONGORY_TYPE_DOUBLE) {
    rb_hash_aset(hash, ID2SYM(rb_intern("priority")), DBL2NUM(priority_val->data.d));
  }

  mongory_value *field_val = node->get(node, "field");
  if (field_val && field_val->type == MONGORY_TYPE_STRING && field_val->data.s) {
    rb_hash_aset(hash, ID2SYM(rb_intern("field")), rb_utf8_str_new_cstr(field_val->data.s));
  }

  mongory_value *record_val = node->get(node, "record");
  if (record_val) {
    rb_hash_aset(hash, ID2SYM(rb_intern("record")), rb_mongory_value_to_rb(record_val));
  }

  mongory_value *result_val = node->get(node, "result");
  if (result_val && result_val->type == MONGORY_TYPE_STRING && result_val->data.s) {
    rb_hash_aset(hash, ID2SYM(rb_intern("result")), ID2SYM(rb_intern(result_val->data.s)));
  }

  mongory_value *children_val = node->get(node, "children");
  VALUE rb_children = rb_ary_new();
  if (children_val && children_val->type == MONGORY_TYPE_ARRAY && children_val->data.a) {
    mongory_array *arr = children_val->data.a;
    for (size_t i = 0; i < arr->count; i++) {
      rb_ary_push(rb_children, rb_mongory_tree_node_to_rb(arr->get(arr, i)));
    }
  }
  rb_hash_aset(hash, ID2SYM(rb_intern("children")), rb_children);

  return hash;
}

static VALUE rb_mongory_tree_renderer_module(void) {
  VALUE m_utils = rb_const_get(rb_mongory_m_mongory, rb_intern("Utils"));
  return rb_const_get(m_utils, rb_intern("TreeRenderer"));
}

static VALUE rb_mongory_matcher_explain_tree_body(VALUE arg) {
  rb_mongory_explain_call_t *call = (rb_mongory_explain_call_t *)arg;
  mongory_value *tree = mongory_matcher_explain_tree(call->wrapper->matcher, call->scratch_pool);
  rb_mongory_error_handling(call->scratch_pool, "Explain failed");
  return rb_mongory_tree_node_to_rb(tree);
}

// Mongory::CMatcher#explain_tree
static VALUE rb_mongory_matcher_explain_tree(VALUE self) {
  rb_mongory_matcher_t *wrapper = get_initialized_matcher(self);
  rb_mongory_scratch_lease_t lease = rb_mongory_scratch_acquire(wrapper);
  rb_mongory_explain_call_t call = {
    .wrapper = wrapper,
    .scratch_pool = &lease.scratch->base,
  };
  VALUE result = rb_ensure(rb_mongory_matcher_explain_tree_body, (VALUE)&call, rb_mongory_scratch_release, (VALUE)&lease);
  RB_GC_GUARD(self);
  return result;
}

// Mongory::CMatcher#explain
static VALUE rb_mongory_matcher_explain(VALUE self) {
  VALUE tree = rb_mongory_matcher_explain_tree(self);
  if (!NIL_P(tree)) {
    rb_funcall(rb_mongory_tree_renderer_module(), rb_intern("print_explain"), 1, tree);
  }
  RB_GC_GUARD(tree);
  return Qnil;
}

// Mongory::CMatcher#trace_tree(data)
static VALUE rb_mongory_matcher_trace_tree(VALUE self, VALUE data) {
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

  mongory_value *tree = mongory_matcher_trace_tree(wrapper->matcher, data_value);
  if (trace_pool_base->error) {
    char err_msg[256];
    snprintf(err_msg, sizeof(err_msg), "%s",
             trace_pool_base->error->message ? trace_pool_base->error->message : "Unknown error");
    trace_pool_base->free(trace_pool_base);
    rb_raise(rb_mongory_e_type_error, "Trace failed: %s", err_msg);
  }
  VALUE result = rb_mongory_tree_node_to_rb(tree);
  trace_pool_base->free(trace_pool_base);

  return result;
}

// Mongory::CMatcher#trace(data)
static VALUE rb_mongory_matcher_trace(VALUE self, VALUE data) {
  VALUE tree = rb_mongory_matcher_trace_tree(self, data);
  if (NIL_P(tree)) {
    return Qfalse;
  }
  rb_funcall(rb_mongory_tree_renderer_module(), rb_intern("print_trace"), 1, tree);
  VALUE res = rb_hash_aref(tree, ID2SYM(rb_intern("result")));
  RB_GC_GUARD(tree);
  return res == ID2SYM(rb_intern("pass")) ? Qtrue : Qfalse;
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
  rb_define_method(rb_mongory_c_matcher, "explain_tree", rb_mongory_matcher_explain_tree, 0);
  rb_define_method(rb_mongory_c_matcher, "explain", rb_mongory_matcher_explain, 0);
  rb_define_method(rb_mongory_c_matcher, "condition", rb_mongory_matcher_condition, 0);
  rb_define_method(rb_mongory_c_matcher, "context", rb_mongory_matcher_context, 0);
  rb_define_method(rb_mongory_c_matcher, "trace_tree", rb_mongory_matcher_trace_tree, 1);
  rb_define_method(rb_mongory_c_matcher, "trace", rb_mongory_matcher_trace, 1);
  rb_define_method(rb_mongory_c_matcher, "enable_trace", rb_mongory_matcher_enable_trace, 0);
  rb_define_method(rb_mongory_c_matcher, "disable_trace", rb_mongory_matcher_disable_trace, 0);
  rb_define_method(rb_mongory_c_matcher, "print_trace", rb_mongory_matcher_print_trace, 0);
}
