# Mongory-rb

A Mongo-like in-memory query DSL for Ruby.

Mongory lets you filter and query in-memory collections using syntax and semantics similar to MongoDB. It is designed for expressive chaining, symbolic operators, and composable matchers.

## Installation
### Rails Generator

You can install a starter configuration with:

```bash
rails g mongory:install
```

This will generate `config/initializers/mongory.rb` and set up:
- Optional symbol operator snippets (e.g. `:age.gt => 18`)
- Class registration (e.g. `Array`, `ActiveRecord::Relation`, etc.)
- Custom value/key converters for your ORM

Add to your Gemfile:

```bash
bundle add mongory-rb
```

Or install manually:

```bash
gem install mongory-rb
```

## Basic Usage

```ruby
records = [
  { 'name' => 'Jack', 'age' => 18, 'gender' => 'M' },
  { 'name' => 'Jill', 'age' => 15, 'gender' => 'F' },
  { 'name' => 'Bob',  'age' => 21, 'gender' => 'M' },
  { 'name' => 'Mary', 'age' => 18, 'gender' => 'F' }
]

result = records.mongory
  .where(:age.gte => 18)
  .or({ :name => /J/ }, { :name.eq => 'Bob' })
  .limit(2)
  .to_a

puts result
```

# This adds an `$or` condition across multiple subqueries.

## Supported Operators

| Category     | Operators                           |
|--------------|-------------------------------------|
| Comparison   | `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte` |
| Set          | `$in`, `$nin`                       |
| Boolean      | `$and`, `$or`, `$not`               |
| Pattern      | `$regex`                            |
| Presence     | `$exists`, `$present`               |
| Nested Match | `$elemMatch`, `$every`                      |

Mongory extension:
- `$present` - checks if the record is not empty or false, nil
- `$every` – checks that all elements in an array match the condition

Operators can be chained from symbols:

```ruby
{ :age.gte => 18, :status.in => %w[active archived] }
```

> Note: Symbol operator snippets (like `:age.gt`) are opt-in and enabled via:
>
> ```ruby
> Mongory.enable_symbol_snippets!
> ```

## Advanced: Custom Matchers

Mongory allows you to register your own matchers using `Mongory::Matchers.register`.

Here's an example matcher that filters records based on their class:

```ruby
class ClassInMatcher < Mongory::Matchers::AbstractMatcher
  def match(subject)
    @condition.any? { |klass| subject.is_a?(klass) }
  end

  def check_validity!
    raise TypeError, '$classIn needs an array.' unless @condition.is_a?(Array)
    @condition.each do |klass|
      raise TypeError, '$classIn needs an array of class.' unless klass.is_a?(Class)
    end
  end
end

Mongory::Matchers.register(:class_in, '$classIn', ClassInMatcher)

[{a: 1}].mongory.where(:a.class_in => [Integer]).first
# => { a: 1 }
```

You can define any matcher behavior and attach it to a `$operator` of your choice.
Matchers can be composed, validated, and traced just like built-in ones.

## Query API Reference
### Registering Models

To allow calling `.mongory` on collections, use `register`:

```ruby
Mongory.register(Array)
Mongory.register(ActiveRecord::Relation)
User.where(status: 'active').mongory.where(:age.gte => 18, :name.regex => "^S.+")
```

This injects a `.mongory` method via an internal extension module.

- `.where(cond)` → adds `$and` condition
- `.or(*conds)` → adds `$or` conditions
- `.not(cond)` → wraps condition in `$not`
- `.asc(*keys)` / `.desc(*keys)` → sorts results
- `.limit(n)` → restricts result size
- `.pluck(:field1, :field2)` → extract fields from each record

Internally, the query is compiled into a matcher tree using the `QueryMatcher` and `ConditionConverter`.

## Extending Mongory

Mongory is designed for extensibility. You can customize:

- **Value conversion**: via `mc.data_converter.register`
- **Key parsing rules**: via `mc.condition_converter.key_converter.register`
- **Match operators**: via `Matchers.register`
- **Query entrypoints**: via `Mongory.register(SomeClass)`

See the examples above for details.

## Configuration

You can configure custom conversion rules for keys or values:

```ruby
Mongory.configure do |mc|
  # Can use symbol to determine which method to use on convert
  mc.data_converter.configure do |dc|
    dc.register(MyDateLikeObject, :attributes_with_string_key)
  end

  # Or can give a block to define how to convert
  mc.condition_converter.key_converter.configure do |kc|
    # Key converter expected to provide a method or block that receive one parameter to construct key value pair
    kc.register(MyOperatorKey) { |value| { transformed_key => value } }
  end

  # Also support recursively convert
  mc.condition_converter.value_converter.configure do |vc|
    vc.register(MyEnumerable) { map { |v| vc.convert(v) } }
  end
end
```

This configuration is frozen after `configure` is called.

## Debugging

Enable match trace to inspect evaluation flow:

```ruby
Mongory.debugger.enable

records.mongory
  .where(:age => 18)
  .to_a

Mongory.debugger.disable
```

Matcher output will be indented with visual feedback.

You can also render the matcher tree structure:

```ruby
query = records.mongory.where(:age => 18)
query.explain
```

## Architecture Overview

Mongory-rb is built from modular components:

- **QueryBuilder**: chainable query API
- **ConditionConverter**: transforms flat conditions into matcher trees
- **Converters**: normalize keys and values
- **Matchers**: perform evaluation per operator
- **Debugger**: optional trace during matching

## Development

- After cloning the repo, install dependencies:

  ```bash
  bundle install
  ```

- Run tests with RSpec:

  ```bash
  bundle exec rspec
  ```

- To generate YARD documentation:

  ```bash
  yard doc
  ```

- For an interactive console, run:

  ```bash
  bin/console
  ```

## Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**.
2. **Create a new branch** for each significant change.
3. **Write tests** for your changes.
4. **Send a pull request**.

Please ensure your code adheres to the project's style guide and that all tests pass before submitting.

## Code of Conduct

Everyone interacting in the Mongory-rb project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/koten0224/mongory-rb/blob/main/CODE_OF_CONDUCT.md).

## License

MIT. See LICENSE file.
