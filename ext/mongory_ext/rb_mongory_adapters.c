/**
 * @file rb_mongory_adapters.c
 * @brief Bridges mongory-core regex, value converter, and custom matcher hooks to Ruby.
 */
#include "mongory_ext_internal.h"
#include <string.h>

// Replaces a string pattern with its compiled Regexp so later matches reuse it,
// and keeps the Regexp alive for the GC.
static VALUE rb_mongory_regex_cache(mongory_memory_pool *pool, mongory_value *pattern, VALUE rb_re) {
  if (pattern->type == MONGORY_TYPE_REGEX && pattern->data.regex) {
    return (VALUE)pattern->data.regex;
  }
  mongory_memory_pool *pattern_pool = pattern->pool;
  mongory_value *temp_value = mongory_value_wrap_regex(pool, (void *)rb_re);
  if (temp_value) {
    memcpy(pattern, temp_value, sizeof(mongory_value));
    pattern->pool = pattern_pool;
    pattern->origin = (void *)rb_re;
    rb_mongory_memory_pool_t *rb_pool = (rb_mongory_memory_pool_t *)pool;
    if (rb_pool->owner) {
      rb_pool->owner->mark_list->push(rb_pool->owner->mark_list, pattern);
    }
  }
  return rb_re;
}

static bool rb_mongory_regex_match_adapter(mongory_memory_pool *pool, mongory_value *pattern, mongory_value *value) {
  if (!pattern || !value || value->type != MONGORY_TYPE_STRING) {
    return false;
  }

  VALUE rb_str = (VALUE)value->origin;
  VALUE rb_re = Qnil;

  if (pattern->type == MONGORY_TYPE_REGEX && pattern->data.regex) {
    rb_re = (VALUE)pattern->data.regex;
  } else if (pattern->type == MONGORY_TYPE_STRING) {
    rb_re = rb_mongory_regex_cache(pool, pattern, rb_funcall(rb_cRegexp, rb_intern("new"), 1, (VALUE)pattern->origin));
  } else {
    return false;
  }

  VALUE matched = rb_funcall(rb_re, rb_intern("match?"), 1, rb_str);
  return RTEST(matched);
}

// Regex adapter for `$options` (validated by core to i, m, s). Ruby's `^`/`$`
// already match at line boundaries, so only i and s need flags; Ruby's
// MULTILINE is MongoDB's `s`. Core rejects `$options` on a compiled regex, so
// pattern is a string until the first match caches it.
static bool rb_mongory_regex_options_match_adapter(mongory_memory_pool *pool, mongory_value *pattern,
                                                   const char *options, mongory_value *value) {
  if (!pattern || !value || value->type != MONGORY_TYPE_STRING) {
    return false;
  }
  if (pattern->type == MONGORY_TYPE_STRING) {
    int flags = 0;
    for (const char *flag = options; *flag; flag++) {
      if (*flag == 'i') {
        flags |= NUM2INT(rb_const_get(rb_cRegexp, rb_intern("IGNORECASE")));
      } else if (*flag == 's') {
        flags |= NUM2INT(rb_const_get(rb_cRegexp, rb_intern("MULTILINE")));
      }
    }
    rb_mongory_regex_cache(pool, pattern,
                           rb_funcall(rb_cRegexp, rb_intern("new"), 2, (VALUE)pattern->origin, INT2FIX(flags)));
  }
  return rb_mongory_regex_match_adapter(pool, pattern, value);
}

static char *rb_mongory_regex_stringify_adapter(mongory_memory_pool *pool, mongory_value *pattern) {
  (void)pool;
  if (pattern->type != MONGORY_TYPE_REGEX) {
    return NULL;
  }
  VALUE rb_re = (VALUE)pattern->data.regex;
  VALUE rb_str = rb_funcall(rb_re, rb_intern("inspect"), 0);
  return StringValueCStr(rb_str);
}

static mongory_matcher_custom_context *rb_mongory_custom_matcher_build(char *key, mongory_value *condition, void *ctx) {
  mongory_memory_pool *pool = condition->pool;
  rb_mongory_memory_pool_t *rb_pool = (rb_mongory_memory_pool_t *)pool;
  rb_mongory_matcher_t *owner = rb_pool->owner;
  VALUE matcher_class = rb_funcall(rb_mongory_m_matchers, rb_intern("lookup"), 1,
                                   rb_mongory_cache_fetch_string(owner, key));
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

static bool rb_mongory_custom_matcher_match(void *ruby_matcher, mongory_value *value) {
  VALUE matcher = (VALUE)ruby_matcher;
  VALUE match_result = rb_funcall(matcher, rb_intern("match?"), 1, value->origin);
  return RTEST(match_result);
}

static bool rb_mongory_custom_matcher_lookup(char *key, void *extern_ctx) {
  (void)extern_ctx;
  VALUE matcher_class = rb_funcall(rb_mongory_m_matchers, rb_intern("lookup"), 1, rb_str_new_cstr(key));
  return RTEST(matcher_class);
}

void rb_mongory_register_adapters(void) {
  mongory_regex_func_set(rb_mongory_regex_match_adapter);
  mongory_regex_options_func_set(rb_mongory_regex_options_match_adapter);
  mongory_regex_stringify_func_set(rb_mongory_regex_stringify_adapter);

  mongory_value_converter_deep_convert_set(rb_to_mongory_value_deep);
  mongory_value_converter_shallow_convert_set(rb_to_mongory_value_shallow);
  mongory_value_converter_recover_set(mongory_value_to_ruby);

  mongory_custom_matcher_match_func_set(rb_mongory_custom_matcher_match);
  mongory_custom_matcher_build_func_set(rb_mongory_custom_matcher_build);
  mongory_custom_matcher_lookup_func_set(rb_mongory_custom_matcher_lookup);
}
