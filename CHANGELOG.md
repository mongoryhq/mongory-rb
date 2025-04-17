## [2.0.0-beta.2] - 2025-04-16

### Changed
- Refactored all converter classes (`DataConverter`, `KeyConverter`, `ValueConverter`, `ConditionConverter`) into singleton classes inheriting from `AbstractConverter`
- Introduced `default_registrations` hook method to encapsulate converter setup logic internally
- Migrated fallback logic into `initialize`, removed reliance on `instance_eval`
- Renamed `converter_builder.rb` to `abstract_converter.rb`
- Refactored `Debugger` into a singleton class with `include Singleton`
- Moved `Debugger`'s setup logic into `initialize`
- All references to converters and debugger updated to use `.instance`

### Breaking Changes
- Removed support for direct `.convert(...)` calls on converter constants (e.g., `KeyConverter.convert`); use `.instance.convert(...)` instead
- Removed `.configure` DSL on `ConditionConverter`; use `default_registrations` override instead
- Replaced `Debugger.method` access with `Debugger.instance.method`

## [2.0.0-beta.1] - Unreleased - 2025-4-16

### ⚠️ Breaking Changes
- Renamed `DefaultMatcher` to `LiteralMatcher`
- Renamed `ConditionMatcher` to `HashConditionMatcher`
- Renamed `CollectionMatcher` to `ArrayRecordMatcher`
- Matcher behavior now enforces diggable structure for field access
- Query no longer matches `nil` as a valid document; field conditions (like `a: nil`) require diggable structure

### ✨ Features
- Support for `$in` and `$nin` operators in query conditions
- Delegated `nil` conditions to `OrMatcher` to improve MongoDB compatibility

### 🧠 Debugger & Trace
- Introduced structured matcher trace logging for better debugging
- Tree-based trace visualization implemented
- Removed dependency on Ruby’s PrettyPrint module

### 🛠 Refactors
- Unified matcher dispatch logic in `dispatched_matcher`
- Simplified `render_tree` logic
- Improved fallback handling for symbol/string keys in field matchers
- Improved trace indent level calculation logic
- Removed all internal sort helpers: `#asc`, `#desc`, and `#sort_by_key`
- Sorting is no longer supported in Mongory query builder
- If needed, use `query.sort_by { |record| ... }` instead

### ✅ Fixes
- `$every => []` now correctly returns `false` instead of `true`

### 🧪 Test & Docs
- Refined RSpec matcher test coverage
- Updated YARD documentation across matchers
- Matcher converter display now includes full namespace

### 📄 Planning
- Added draft design notes for the upcoming `aggregate` system

## [1.8.0] - 2025-04-14

### Changed

- **Refactored Matcher Architecture**
  - `DigValueMatcher` has been renamed to `FieldMatcher` to better reflect its behavior.
  - All matchers now use `enable_unwrap!` to explicitly control matcher flattening logic in multi-match contexts.
  - `ConditionMatcher`, `CollectionMatcher`, and `DefaultMatcher` routing logic now reflects the new matcher structure.

- **Improved Matcher Trace & Tree Introspection**
  - All matchers now support `.render_tree` and `.tree_title` to integrate with `QueryBuilder#explain`.
  - `FieldMatcher`, `RegexMatcher`, `InMatcher`, and `NinMatcher` now display accurate introspection trees.
  - Enhanced `uniq_key` implementations across matchers to prevent duplication and support correct tree merging.

- **Operator Behavior Refinement**
  - `InMatcher` and `NinMatcher` now clearly distinguish between single value vs. array inputs.
  - `RegexMatcher` now accepts both literal `/regex/` and `"$regex"` formats; fallback from `DefaultMatcher` is supported.

### Documentation

- Added or improved YARD documentation across all matchers.
- All public APIs, including `render_tree`, `match`, `uniq_key`, and `tree_title` are now documented with examples and usage notes.
- `matchers/README.md` updated to reflect renames and structural clarity.

## [1.7.0] - 2025-04-13

### Added

- `QueryBuilder#explain` prints a tree-structured matcher breakdown using `PP`, useful for debugging.
- Matchers now support `#render_tree` and `#tree_title`, enabling structured introspection.
- `QueryBuilder#any_of` added as a semantic alias for `.and('$or' => [...])`.

### Changed

- Filter logic restructured to use immediately-parsed matchers (`set_matcher`) instead of building on `result`.
- `.each` now directly filters via matcher tree evaluation, removing dependency on an internal condition hash.
- Removed legacy `.result` method.
- `.or(...)` now wraps existing conditions intelligently when merging mixed operator states.
- `.pluck` and `.sort_by_keys` no longer convert keys to strings, fixing inconsistency with native Mongoid behavior.

### Deprecated

- `.asc` and `.desc` now emit deprecation warnings; they will be removed in v2.0.0.

## [1.6.4] - 2025-04-11

### Fixed

- `MongoidPatch` now references `Mongory::Converters::KeyConverter` directly instead of lazily accessing it through `.condition_converter`.
- Restored missing `Mongory.configure` method accidentally removed in earlier documentation refactor.
- Ensured all `.configure` entrypoints are consistently available for all converters.

## [1.6.1] - 2025-04-11

### Added

- **Rails Integration via Railtie**  
  Mongory now auto-integrates with Rails if present, using a new `Mongory::Railtie` and `RailsPatch` module.

- **Mongoid Integration Module**  
  Added `mongory/mongoid` which registers `Mongoid::Criteria::Queryable::Key` for symbolic query operators (e.g. `:age.gt`).

- **Conditional Auto-Require**  
  `mongory.rb` now conditionally requires `rails` and `mongoid` integration modules when Rails or Mongoid is detected.

- **YARD Documentation**  
  Improved YARD docstrings for all public APIs, including `QueryOperator`, `InstallGenerator`, and matchers.

### Changed

- **Generator Initializer Cleanup**  
  Removed direct Mongoid-specific converter registration from generator output. This logic is now encapsulated in `mongory/mongoid.rb`.

- **Improved Symbol DSL Activation**  
  Symbol snippets (`:age.gt => 30`) are now opt-in, via `Mongory.enable_symbol_snippets!`, and properly isolated from default runtime.

- **Safer Core Patch for present?/blank?**  
  When in Rails, Mongory will use `Object#present?` and `Object#blank?` instead of internal implementations, for better semantic consistency.

## [1.6.0] - 2025-04-11

### Added
- **Custom Operator: `$every`**
  Added support for `$every`, a new matcher that succeeds only if *all* elements in an array satisfy the condition.
- **Custom Error Class: `Mongory::TypeError`**
  Replaces Ruby's `TypeError` for internal validation, enabling cleaner and safer error handling.
- **Internal API: `SingletonBuilder`**
  Introduced a unified abstraction for building singleton converters and utilities (used by `Debugger`, all Converters, etc.).

### Changed
- **Unified Matcher Construction**
  All matchers now use `.build(...)` instead of `.new(...)` for consistent instantiation.
- **Simplified Matcher Dispatch**
  Multi-matchers (`$and`, `$or`, etc.) now unwrap themselves when only one submatcher is present.
- **Centralized Matcher Responsibility**
  `ConditionMatcher` replaces `DefaultMatcher` as the default dispatcher for query conditions.
- **Consistent Data Conversion**
  All nested matchers (e.g. `FieldMatcher`, `ElemMatchMatcher`) now apply `data_converter` at match-time.

### Fixed
- **Validation Improvements**
  Introduced `deep_check_validity!` to ensure all nested matchers are properly verified.
- **Edge Case Consistency**
  Cleaner fallback handling and key traversal behavior under complex or mixed-type query structures.

---

## [1.5.0] - 2025-04-09

### Added
- **YARD Documentation**: Added `.yardopts` configuration file for generating documentation.
- **Converters Module**: Introduced `Mongory::Converters` module with `DataConverter` and `ConditionConverter` classes for better data and condition normalization.
- **Debugger**: Exposed `Utils::Debugger` for better debug control and query tracing.

### Changed
- **QueryBuilder Refactor**: Simplified `build_query` method to use `QueryBuilder` directly without namespace.
- **Data and Condition Converters**: Directly exposed `data_converter` and `condition_converter` via `Mongory` module for easier access and configuration.
- **Removed Config Class**: Removed `Config` class and replaced with direct configuration in `Mongory`.

### Fixed
- **Bug Fixes**: Corrected issues with array comparisons and query operator behaviors.

---

## [Prior Versions Summary]

- `1.0.1`: Initial release
- `1.1.0 ~ 1.3.3`: Refactored matcher architecture, added class inheritance structure, separated key/value matcher logic.
- `1.4.x`: Skipped
