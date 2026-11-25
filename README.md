# Mongory (Ruby)

[![Gem Version](https://img.shields.io/gem/v/mongory)](https://rubygems.org/gems/mongory)
[![API Docs](https://img.shields.io/badge/API%20Docs-YARD-CC342D)](https://mongoryhq.github.io/mongory-rb/)
[![CI](https://github.com/mongoryhq/mongory-rb/actions/workflows/main.yml/badge.svg)](https://github.com/mongoryhq/mongory-rb/actions/workflows/main.yml)
[![mongory-spec](https://github.com/mongoryhq/mongory-rb/actions/workflows/spec-conformance.yml/badge.svg)](https://github.com/mongoryhq/mongory-rb/actions/workflows/spec-conformance.yml)
![Ruby](https://img.shields.io/badge/Ruby-2.6%2B-CC342D)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Zero-dependency, C99-backed in-memory MongoDB-style query and rule engine for Ruby**, with built-in `explain` / `trace` debugging and cross-language parity via [`mongory-spec`](https://github.com/mongoryhq/mongory-spec).

**[Try the Interactive Playground & Visual Explain/Trace Debugger ↗](https://mongoryhq.github.io/mongory-central/)**

[![Mongory Playground & Visual Trace](https://mongoryhq.github.io/mongory-central/playground-trace.png)](https://mongoryhq.github.io/mongory-central/)

> **Ecosystem:** [Playground](https://mongoryhq.github.io/mongory-central/) · [`mongory-go` (Go)](https://github.com/mongoryhq/mongory-go) · [`mongory-js` (TypeScript/JS)](https://github.com/mongoryhq/mongory-js) · [`mongory-py` (Python)](https://github.com/mongoryhq/mongory-py) · [`mongory-core` (C99)](https://github.com/mongoryhq/mongory-core) · [`mongory-spec`](https://github.com/mongoryhq/mongory-spec)

## Installation

```bash
gem install mongory
# or in Gemfile:
gem 'mongory'
```

The gem ships precompiled native binaries (Ruby `2.6-4.0`) for Linux (`x86_64`/`aarch64`, glibc and musl), macOS (`x86_64`/`arm64`), and Windows (`x64-mingw32`/`ucrt`). In a Rails project, generate the initializer with `rails g mongory:install`.

<details>
<summary>Platform note (Apple Silicon system Ruby / source builds)</summary>

On older Apple Silicon macOS system Ruby (`universal-darwin`), run `gem install mongory --platform arm64-darwin` or `bundle lock --add-platform arm64-darwin`. When compiling from source on other platforms, ensure `gcc`/`clang` and `make` are installed.

</details>

## Quick Start

```ruby
require 'mongory'
require 'json'

Mongory.register(Array)
Mongory.enable_symbol_snippets!

records = [
  { 'name' => 'Jack', 'age' => 18, 'tags' => %w(ruby go), 'active' => true },
  { 'name' => 'Jill', 'age' => 15, 'tags' => %w(js),      'active' => true },
  { 'name' => 'Bob',  'age' => 21, 'tags' => %w(ruby),    'active' => false }
]

# 1. Chainable DSL with symbol operator snippets
records.mongory
  .where(:age.gte => 18, :active => true)
  .any_of({ :tags => 'ruby' }, { :name => /^J/ })
  .to_a
# => [{ "name" => "Jack", ... }]

# 2. Direct JSON condition (e.g. rule payload from API / database)
rule = JSON.parse('{"age": {"$gte": 18}, "$or": [{"name": {"$regex": "^J"}}, {"name": "Bob"}]}')
records.mongory.where(rule).pluck('name')
# => ["Jack", "Bob"]

# 3. Compile once as a reusable, thread-safe Matcher (ideal for constants)
ADULT_RULE = Mongory.compile(:age.gte => 18, :active => true)
ADULT_RULE.match?(records.first)
# => true
```

## Why Mongory? (and When Not to Use It)

- **Use Mongory when**: rules are stored as data (DB/config/API/feature flags), shared between frontend TS and Ruby/Go/Python services, or complex enough that nested `select` blocks become unreadable and hard to debug without `trace`.
- **Don't use Mongory when**: your filter is a simple static `records.select { |r| r['age'] >= 18 }` hardcoded in Ruby, or when you need full SQL/MongoDB aggregation pipelines (`$group`, `$lookup`, `$project`).
- **vs `Mongoid::Matcher`**: `mongory` has zero external gem dependencies (no `mongoid`, `mongo`, or `activesupport` required), works on plain `Hash`/PORO/ActiveRecord objects, compiles queries once into C99 (`mongory-core`), and adds `explain`/`trace` trees.

## Benchmark Snapshot

Measured on Apple M3 (macOS arm64, Ruby `4.0.5`, `100,000` records x 5 rounds; full details & script in [docs/performance.md](docs/performance.md)):

| Case | Plain Ruby `Array#count` | `Mongory::Matcher` (C99) | `Mongoid::Matcher` (`9.1.2`) | `Mongory` vs `Mongoid` |
|---|---:|---:|---:|---:|
| `simple` (`age >= 18`) | `63.1 ns/rec` | `77.9 ns/rec` | `3,224.5 ns/rec` | **41.4x faster** |
| `$or` (`age >= 18` or `status == "active"`) | `71.8 ns/rec` | `127.4 ns/rec` | `3,967.9 ns/rec` | **31.1x faster** |
| `in_array_field` (`tags $in ["ruby", "rust"]`) | `85.3 ns/rec` | `136.4 ns/rec` | `4,302.1 ns/rec` | **31.5x faster** |
| `large_in_500` (`name $in [500 items]`) | `62.9 ns/rec` | `115.8 ns/rec` | `97,351.9 ns/rec` | **840.7x faster** |

## Debugging: `explain`, `trace`, `explain_tree` & `trace_tree`

Mongory automatically sorts sibling conditions by cost (cheap `$eq`/`$exists` short-circuit before `$regex` or array scans). Inspect compiled plans or per-record `PASS`/`FAIL`/`SKIP` traces in CLI output or structured Ruby Hashes:

```ruby
query = records.mongory
  .where(:age.gte => 18)
  .any_of({ status: 'active' }, { :name.regex => /^J/ })

query.explain                    # prints priority-sorted plan tree to STDOUT
plan = query.explain_tree        # structured Hash (for logging / APIs / UIs)

query.trace { |r| puts r['name'] } # prints per-record PASS/FAIL/SKIP trace
trees = query.trace_tree           # Array<Hash> with :pass | :fail | :skip nodes
```

```text
And: {"age"=>{"$gte"=>18}, "$or"=>[{"status"=>"active"}, {"name"=>{"$regex"=>/^J/}}]}
├─ Field: "age" to match: {"$gte"=>18}
│  └─ Gte: 18
└─ Or: [{"status"=>"active"}, {"name"=>{"$regex"=>/^J/}}]
   ├─ Field: "status" to match: "active"
   │  └─ Eq: "active"
   └─ Field: "name" to match: {"$regex"=>/^J/}
      └─ Regex: /^J/
```

Single-record tracing is also available directly on matchers via `matcher.explain_tree` and `matcher.trace_tree(record)`.

## Operators & Query Builder

| Category | Operators | Notes |
|---|---|---|
| Comparison | `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte` | Cross-type `Integer`/`Float` equality; implicit `$elemMatch` on arrays |
| Inclusion | `$in`, `$nin` | Scalar membership or array intersection; O(1) hash lookup for `>= 16` items |
| Logical | `$and`, `$or`, `$not` | Priority-sorted sibling evaluation with dynamic re-sorting |
| Array | `$elemMatch`, `$every`, `$size` | `$every` requires non-empty array; `$size` accepts integer or nested matcher |
| Existence | `$exists`, `$present` | `$present` checks non-nil and non-empty (`String`, `Array`, `Hash`) |
| Regex | `$regex` (`$options`: `i`, `m`, `s`) | Accepts `Regexp` or pattern string with optional `$options` |

Query builder methods: `where`, `any_of`, `or`, `and`, `not`, `in` / `nin`, `limit`, `pluck`, `with_context`.

> **Differences from MongoDB:** `$every` (returns `false` on `[]`) and `$present` are Mongory extensions; `$options` only permits `i`/`m`/`s`; unknown `$` operators raise `Mongory::TypeError`. See [`mongory-spec`](https://github.com/mongoryhq/mongory-spec#37-differences-from-mongodb-query-syntax).

## Custom Matchers & Configuration

```ruby
Mongory.configure do |mc|
  mc.enable_symbol_snippets!
  mc.register(Array)
  mc.register(ActiveRecord::Relation)
end

class ClassInMatcher < Mongory::Matchers::AbstractMatcher
  def match(subject)
    @condition.any? { |klass| subject.is_a?(klass) }
  end

  def check_validity!
    raise Mongory::TypeError, '$classIn needs an Array of Classes' unless
      @condition.is_a?(Array) && @condition.all? { |k| k.is_a?(Class) }
  end
end

Mongory::Matchers.register(:class_in, '$classIn', ClassInMatcher)
```

## Guides & Further Reading

- [Performance & Benchmarks](docs/performance.md)
- [Handling Dots in Field Names](docs/field_names.md)
- [Advanced Usage & Converters](docs/advanced_usage.md)
- [Clang Bridge (C Extension Internals)](docs/clang_bridge.md)
- [Migration Guide](docs/migration.md)

## Security & Untrusted Input

- **Engine protections**: Pure in-memory C99 evaluation (no SQL, no `$where`/`eval`), arena memory pool chunk limits, and compile-time depth/node budgets (`MaxDepth = 64`, `MaxNodes = 4096`).
- **Application responsibility**: When accepting query conditions from untrusted users, validate expected scalar types (to prevent operator injection such as `{"$ne" => nil}`), allowlist queryable fields, and configure `Regexp.timeout` (Ruby 3.2+) or restrict untrusted `$regex` patterns.

## Contributing & License

Bug reports and pull requests are welcome on [GitHub](https://github.com/mongoryhq/mongory-rb). Everyone interacting in the project is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

Released under the [MIT License](LICENSE).
