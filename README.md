# Mongory (Ruby)

**Cross-language, in-memory Mongo-style rule engine & query matcher with built-in Explain & Trace debugging** — optional C99 acceleration ([`mongory-core`](https://github.com/mongoryhq/mongory-core)), pure Ruby fallback, and cross-language parity via [`mongory-spec`](https://github.com/mongoryhq/mongory-spec).

**[Try the Interactive Playground & Visual Explain/Trace Debugger ↗](https://mongoryhq.github.io/mongory-central/)**

[![Mongory Playground & Visual Trace](https://mongoryhq.github.io/mongory-central/playground-trace.png)](https://mongoryhq.github.io/mongory-central/)

> **Zero database required:** Evaluate MongoDB-style conditions (`$gte`, `$elemMatch`, `$every`, `$present`, `$regex`, etc.) directly against in-memory Ruby Arrays, Hashes, custom objects, and ActiveRecord/Mongoid relations.  
> **Ecosystem:** [Interactive Playground](https://mongoryhq.github.io/mongory-central/) · [`mongory-go` (Go)](https://github.com/mongoryhq/mongory-go) · [`mongory-js` (TypeScript/JS)](https://github.com/mongoryhq/mongory-js) · [`mongory-core` (C99)](https://github.com/mongoryhq/mongory-core) · [`mongory-spec`](https://github.com/mongoryhq/mongory-spec)

## Features

- **Chainable Ruby DSL & Raw JSON Support**: Compose queries with `.where`, `.any_of`, `.or`, `.not`, and optional Symbol snippets (`:age.gte => 18`), or pass parsed JSON conditions directly from front-end rules.
- **All 17 Mongory Operators**: `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`, `$exists`, `$present`, `$and`, `$or`, `$not`, `$elemMatch`, `$every`, `$size`, `$regex` (with `$options`: `i`, `m`, `s`).
- **Priority-Ordered Execution & Visual Debugging**: Automatically sorts sibling conditions so cheaper checks short-circuit before expensive regex or array scans; inspect compiled trees with `.explain` and per-record evaluation with `.trace`.
- **Optional C99 Native Extension (`CMatcher`)**: Switch any query to the C fast path via `.c` or enable globally with `Mongory.enable_c_extension_by_default!`.
- **Precompiled Native Gems (Ruby 2.6–4.0)**: Ships prebuilt binaries for Linux (`x86_64`/`aarch64`, glibc & musl), macOS (`x86_64`/`arm64`), and Windows (`x64-mingw32`/`ucrt`).

## Installation

```bash
gem install mongory
# or in Gemfile:
gem 'mongory'
```

In a Rails project, generate the initializer (`config/initializers/mongory.rb`):

```bash
rails g mongory:install
```

> **Note:** Precompiled native gems are installed automatically on supported Linux, macOS, and Windows platforms. When compiling from source on other platforms, ensure `gcc`/`clang` and `make` are installed.

## Quick Start

```ruby
require 'mongory'
require 'json'

Mongory.register(Array)
Mongory.enable_symbol_snippets!

records = [
  { 'name' => 'Jack', 'age' => 18, 'tags' => %w[ruby go], 'active' => true },
  { 'name' => 'Jill', 'age' => 15, 'tags' => %w[js],      'active' => true },
  { 'name' => 'Bob',  'age' => 21, 'tags' => %w[ruby],    'active' => false }
]

# 1. Chainable DSL with symbol operator snippets
matched = records.mongory
  .where(:age.gte => 18, :active => true)
  .any_of({ :tags => 'ruby' }, { :name => /^J/ })
  .to_a
# => [{ "name" => "Jack", ... }]

# 2. Direct JSON condition (e.g. rule payload from API / front-end)
rule = JSON.parse('{"age": {"$gte": 18}, "$or": [{"name": {"$regex": "^J"}}, {"name": "Bob"}]}')
records.mongory.where(rule).pluck('name')
# => ["Jack", "Bob"]

# 3. C extension fast path (.c per query, or enable globally)
records.mongory.c.where(:age.gte => 18).to_a
```

### Query Builder Methods

| Method | Description | Example |
|--------|-------------|---------|
| `where` | Adds an `$and` filter condition | `where(:age.gte => 18, status: 'active')` |
| `any_of` | Adds an `$or` branch inside the current `$and` | `any_of({ role: 'admin' }, { :score.gte => 90 })` |
| `or` | Combines the current query with `$or` conditions | `or({ age: 18 }, { name: 'Bob' })` |
| `and` | Combines conditions with `$and` | `and({ :age.gte => 18 }, { active: true })` |
| `not` | Negates a condition (`$not`) | `not(:status => 'banned')` |
| `in` / `nin` | Matches values in / not in a list | `in(role: %w[admin editor])` |
| `limit` | Limits processed records (executes at its position in the chain) | `limit(10)` |
| `pluck` | Extracts one or more fields from matching records | `pluck(:name)` |
| `with_context` | Passes shared context/options to matchers | `with_context(tenant: current_tenant)` |
| `c` | Evaluates the query with the C extension (`CQueryBuilder`) | `records.mongory.c.where(...)` |

## Debugging: `explain` & `trace`

Use `explain` to inspect the compiled, priority-sorted matcher tree, and `trace` to see color-coded per-node evaluation:

```ruby
query = records.mongory
  .where(:age.gte => 18)
  .any_of({ status: 'active' }, { :name.regex => /^J/ })

query.explain
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

```ruby
query.trace { |record| puts record['name'] }
```

## Supported Operators

| Category | Operators | Notes |
|----------|-----------|-------|
| Comparison | `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte` | Cross-type `Integer`/`Float` equality; implicit `$elemMatch` on arrays |
| Inclusion | `$in`, `$nin` | Scalar membership or array intersection |
| Logical | `$and`, `$or`, `$not` | Priority-sorted sibling evaluation with dynamic re-sorting |
| Array | `$elemMatch`, `$every`, `$size` | `$every` requires a non-empty array where all elements match; `$size` accepts an integer or range object |
| Existence | `$exists`, `$present` | `$present` checks non-nil and non-empty (`String`, `Array`, `Hash`) |
| Regex | `$regex` (`$options`: `i`, `m`, `s`) | Accepts `Regexp` or pattern string with optional `$options` |

## Custom Matchers & Configuration

Configure registered collection classes, converters, or enable the C extension globally in `Mongory.configure`:

```ruby
Mongory.configure do |mc|
  mc.enable_symbol_snippets!
  mc.enable_c_extension_by_default! # Optional: use CQueryBuilder / CMatcher by default
  mc.register(Array)
  mc.register(ActiveRecord::Relation)
end
```

Define a custom operator with `Mongory::Matchers::AbstractMatcher` (or run `rails g mongory:matcher class_in`):

```ruby
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

- [Handling Dots in Field Names](docs/field_names.md)
- [Advanced Usage & Converters](docs/advanced_usage.md)
- [Clang Bridge (C Extension Internals)](docs/clang_bridge.md)
- [Performance & Benchmarks](docs/performance.md)
- [Migration Guide](docs/migration.md)

## Contributing & License

Bug reports and pull requests are welcome on [GitHub](https://github.com/mongoryhq/mongory-rb). Everyone interacting in the project is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

Released under the [MIT License](LICENSE).
