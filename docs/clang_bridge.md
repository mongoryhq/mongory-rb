# Clang Bridge (Native C99 Engine)

As of `mongory-rb v2.0.0`, Mongory uses the C99 [`mongory-core`](https://github.com/mongoryhq/mongory-core) native extension as its sole matching engine.

**System Dependencies (only when compiling from source):**
- C99-compatible compiler (`gcc` / `clang`)
- CMake >= 3.12 (optional; only needed if you want to build `mongory-core` standalone or run its native tests)

> Note: Precompiled native gems are distributed for Linux, macOS (`arm64` & `x86_64`), and Windows (Ruby 2.6–4.0). When compiling from source, Ruby's `mkmf` (`ext/mongory_ext/extconf.rb`) compiles `mongory-core` sources directly — CMake is not required for gem installation.

## Architecture

The Clang bridge connects the Ruby DSL to `mongory-core` via a compact C layer exposing two key entry points:

- `Mongory::Matcher`: the compiled matcher class backed by `mongory-core`.
- `Mongory::QueryBuilder`: the chainable Ruby DSL (`records.mongory.where(...)`) backed by `Mongory::Matcher`.

## Build / Install

```bash
bundle install
bundle exec rake compile
```

## Basic Usage

```ruby
records = [
  { 'name' => 'Jack', 'age' => 18 },
  { 'name' => 'Jill', 'age' => 15 },
  { 'name' => 'Bob',  'age' => 21 }
]

# Chainable query builder (uses Mongory::Matcher internally)
query = records.mongory.where(:age.gte => 18)

query.each.to_a        # enumerate matches via mongory-core
query.explain_tree     # return structured matcher tree Hash
query.explain          # print matcher tree to STDOUT
query.trace_tree       # return Array<Hash> of structured per-record trace trees (with recursive :skip)
query.trace.to_a       # print trace trees to STDOUT and yield matches

# Or use Mongory::Matcher directly
matcher = Mongory::Matcher.new(:age.gte => 18)
records.select { |r| matcher.match?(r) }
```

## Tracing and Debugging

```ruby
matcher = Mongory::Matcher.new(:$or => [{ :name.regex => /^J/ }, { :age.gt => 20 }])
matcher.enable_trace
records.each { |r| matcher.match?(r) }
matcher.print_trace    # prints detailed trace
matcher.disable_trace

# Structured explain/trace trees on a single Matcher
plan = matcher.explain_tree               # => Hash ({ name:, condition:, priority:, children:, ... })
tree = matcher.trace_tree(records.first)  # => Hash ({ ..., record:, result: :pass | :fail | :skip })

# Print single-record trace tree to STDOUT and return boolean match result
matcher.trace(records.first)
```

## Notes

- Regexes use Ruby's `Regexp` internally; string patterns are compiled once and cached.
- Context (`Mongory::Utils::Context`) is shared between Ruby and C during matching, enabling custom converters and custom Ruby matchers (`Mongory::Matchers::AbstractMatcher`).
