# Clang Bridge (C Extension)

The Clang bridge connects the Ruby DSL to the `mongory-core` engine via a compact C layer. It exposes two key entry points:

- `Mongory::CMatcher`: a low-level matcher API backed by C.
- `QueryBuilder#c`: an ergonomic switch that reuses your current Ruby condition and executes it through `CMatcher`.

## Build/Install

```bash
bundle install
bundle exec rake compile
# or, when installing the gem, the extension will compile automatically if toolchain is present
```

## Quick check

```ruby
require 'mongory'
if defined?(Mongory::CMatcher)
  puts 'C extension available'
else
  puts 'C extension not available, using pure Ruby'
end
```

## Basic usage

```ruby
records = [
  { 'name' => 'Jack', 'age' => 18 },
  { 'name' => 'Jill', 'age' => 15 },
  { 'name' => 'Bob',  'age' => 21 }
]

# Switch existing Ruby query to C path
query = records.mongory.c # => returns Mongory::CQueryBuilder
  .where(:age.gte => 18)

query.each.to_a        # enumerate matches via C
query.fast.to_a        # alias of each
query.trace.to_a       # print value compare progression
query.explain          # print core-level matcher tree

# Or use CMatcher directly
matcher = Mongory::CMatcher.new(:age.gte => 18)
records.select { |r| matcher.match?(r) }
```

## Tracing and debugging

```ruby
matcher = Mongory::CMatcher.new(:$or => [ { :name.regex => /^J/ }, { :age.gt => 20 } ])
matcher.enable_trace
records.each { |r| matcher.match?(r) }
matcher.print_trace    # prints detailed trace
matcher.disable_trace

# Or trace single record compare progression
matcher.trace(records.first)
```

## Notes

- Regexes use Ruby's `Regexp` internally; string patterns are compiled once and cached.
- Context (`Mongory::Utils::Context`) is shared between Ruby and C during matching, enabling custom converters.
- If the extension fails to load, `Mongory::CQueryBuilder` is unavailable and `.c` will not be used; the Ruby path continues to work.


