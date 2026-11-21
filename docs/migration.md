# Migration Guide

## Upgrading from `mongory` v0.x / v1.x to v2.0.0

`mongory-rb v2.0.0` removes the Pure-Ruby built-in matcher engine and unifies on the C99 `mongory-core` native extension as the sole engine.

| v0.x / v1.x | v2.0.0 |
|---|---|
| `Mongory::CMatcher` / `Mongory::QueryMatcher` | `Mongory::Matcher` |
| `Mongory::CQueryBuilder` | `Mongory::QueryBuilder` (now backed by `Mongory::Matcher` directly) |
| `records.mongory.c.where(...)` | `records.mongory.where(...)` |
| `Mongory.enable_c_extension_by_default!` / `disable_c_extension_by_default!` / `c_extension_by_default?` | Removed (C engine is always active) |
| `Mongory.debugger` / `Mongory::Utils::Debugger` | Removed (use `#explain`, `#explain_tree`, `#trace`, `#trace_tree`) |
| Pure-Ruby fallback when `mongory_ext` is missing | Removed (`require 'mongory'` raises `LoadError` if native extension is missing) |

Custom Ruby matchers subclassing `Mongory::Matchers::AbstractMatcher`, `Mongory::Matchers.register`, `Mongory.enable_symbol_snippets!`, and all `Converters` remain supported without changes.

---

## From Array#select
```ruby
# Before
records.select { |r| r['age'] >= 18 && r['status'] == 'active' }

# After
records.mongory.where(:age.gte => 18, status: 'active')
```

## From ActiveRecord
```ruby
# Before
indexed_query.where("age >= ? AND status = ?", 18, 'active')

# After
indexed_query.mongory.where(:age.gte => 18, status: 'active')
```

## From MongoDB
```ruby
# Before (MongoDB)
users.where(:age.gte => 18, status: 'active')

# After (Mongory)
users.mongory.where(:age.gte => 18, status: 'active')

# Just the same.
```
