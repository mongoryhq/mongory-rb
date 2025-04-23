# Mongory-rb

A Mongo-like in-memory query DSL for Ruby.

Mongory lets you filter and query in-memory collections using syntax and semantics similar to MongoDB. It is designed for expressive chaining, symbolic operators, and composable matchers.

## Positioning

Mongory is designed to serve two types of users:

1. For MongoDB users:
   - Seamless integration with familiar query syntax
   - Extends query capabilities for non-indexed fields
   - No additional learning cost

2. For non-MongoDB users:
   - Initial learning cost for MongoDB-style syntax
   - Long-term benefits:
     - Improved code readability
     - Better development efficiency
     - Lower maintenance costs
   - Ideal for teams valuing code quality and maintainability

## Requirements

- Ruby >= 2.6.0
- No external database required

## Quick Start

### Installation
#### Rails Generator

You can install a starter configuration with:

```bash
rails g mongory:install
```

This will generate `config/initializers/mongory.rb` and set up:
- Optional symbol operator snippets (e.g. `:age.gt => 18`)
- Class registration (e.g. `Array`, `ActiveRecord::Relation`, etc.)
- Custom value/key converters for your ORM

Or install manually:
```bash
gem install mongory
```

Or add to your Gemfile:
```ruby
gem 'mongory'
```

### Basic Usage
```ruby
records = [
  { 'name' => 'Jack', 'age' => 18, 'gender' => 'M' },
  { 'name' => 'Jill', 'age' => 15, 'gender' => 'F' },
  { 'name' => 'Bob',  'age' => 21, 'gender' => 'M' },
  { 'name' => 'Mary', 'age' => 18, 'gender' => 'F' }
]

# Basic query with conditions
result = records.mongory
  .where(:age.gte => 18)
  .or({ :name => /J/ }, { :name.eq => 'Bob' })

# Using limit to restrict results
# Note: limit executes immediately and affects subsequent conditions
limited = records.mongory
  .limit(2)                    # Only process first 2 records
  .where(:age.gte => 18)       # Conditions apply to limited set
```

### Integration with MongoDB

Mongory is designed to complement MongoDB, not replace it. Here's how to use them together:

1. Use MongoDB for:
   - Queries with indexes
   - Persistent data operations
   - Large-scale data processing

2. Use Mongory for:
   - Queries without indexes
   - Complex in-memory calculations
   - Temporary data filtering needs

Example:
```ruby
# First use MongoDB for indexed queries
users = User.where(status: 'active')  # Uses MongoDB index

# Then use Mongory for non-indexed fields
active_users = users.mongory
  .where(:last_login.gte => 1.week.ago)  # No index on last_login
  .where(:tags.elem_match => { :name => 'ruby' })  # Complex array query
```

### Creating Custom Matchers
#### Using the Generator

You can generate a new matcher using:

```bash
rails g mongory:matcher class_in
```

This will:
1. Create a new matcher file at `lib/mongory/matchers/class_in_matcher.rb`
2. Create a spec file at `spec/mongory/matchers/class_in_matcher_spec.rb`
3. Update `config/initializers/mongory.rb` to require the new matcher

The generated matcher will:
- Be named `ClassInMatcher`
- Register the operator as `$classIn`
- Be available as `:class_in` in queries

Example usage of the generated matcher:
```ruby
records.mongory.where(:value.class_in => [Integer, String])
```

#### Manual Creation

If you prefer to create matchers manually, here's an example:

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

### Handling Dots in Field Names

Mongory supports field names containing dots, which require escaping:

```ruby
# Sample data
records = [
  { "user.name" => "John", "age" => 25 },  # Field name contains a dot
  { "user" => { "name" => "Bob" }, "age" => 30 }  # Nested field
]

# Field name contains a dot
records.mongory.where("user\\.name" => "John")  # Two backslashes needed with double quotes
# => [{ "user.name" => "John", "age" => 25 }]

# or
records.mongory.where('user\.name' => "John")   # One backslash needed with single quotes
# => [{ "user.name" => "John", "age" => 25 }]

# Nested field (no escaping needed)
records.mongory.where("user.name" => "Bob")
# => [{ "user" => { "name" => "Bob" }, "age" => 30 }]
```

Note:
- With double quotes, backslashes need to be escaped (`\\`)
- With single quotes, backslashes don't need to be escaped (`\`)
- This behavior is consistent with MongoDB's query syntax
- The escaped dot pattern (`\.`) matches fields where the dot is part of the field name
- The unescaped dot pattern (`.`) matches nested fields in the document structure

### Advanced Usage

#### Complex Queries
```ruby
# Nested conditions
users.mongory
  .where(
    :age.gte => 18,
    :$or => [
      { :status => 'active' },
      { :status => 'pending', :created_at.gte => 1.week.ago }
    ]
  )

# Using any_of for nested OR conditions
users.mongory
  .where(:age.gte => 18)
  .any_of(
    { :status => 'active' },
    { :status => 'pending', :created_at.gte => 1.week.ago }
  )

# Array operations
posts.mongory
  .where(:tags.elem_match => { :name => 'ruby', :priority.gt => 5 })
  .where(:comments.every => { :approved => true })
```

#### Integration with ActiveRecord
```ruby
class User < ActiveRecord::Base
  def active_friends
    friends.mongory
      .where(:status => 'active')
      .where(:last_seen.gte => 1.day.ago)
  end
end
```

### Query API Reference
#### Registering Models

To allow calling `.mongory` on collections, use `register`:

```ruby
Mongory.register(Array)
Mongory.register(ActiveRecord::Relation)
User.where(status: 'active').mongory.where(:age.gte => 18, :name.regex => "^S.+")
```

This injects a `.mongory` method via an internal extension module.

Internally, the query is compiled into a matcher tree using the `QueryMatcher` and `ConditionConverter`.

| Method | Description | Example |
|--------|-------------|---------|
| `where` | Adds a condition to filter records | `where(age: { :$gte => 18 })` |
| `not` | Adds a negated condition | `not(age: { :$lt => 18 })` |
| `and` | Combines conditions with `$and` | `and({ age: { :$gte => 18 } }, { name: /J/ })` |
| `or` | Combines conditions with `$or` | `or({ age: { :$gte => 18 } }, { name: /J/ })` |
| `any_of` | Combines conditions with `$or` inside an `$and` block | `any_of({ age: { :$gte => 18 } }, { name: /J/ })` |
| `in` | Checks if a value is in a set | `in(age: [18, 19, 20])` |
| `nin` | Checks if a value is not in a set | `nin(age: [18, 19, 20])` |
| `limit` | Limits the number of records returned. This method executes immediately and affects subsequent conditions. | `limit(2)` |
| `pluck` | Extracts selected fields from matching records | `pluck(:name)` |
| `with_context` | Sets a custom context for the query. Useful for controlling data conversion and sharing configuration across matchers. | `with_context(merchant: merchant)` |

#### Context Configuration

The `with_context` method allows you to customize the query execution environment:

```ruby
# Share configuration across matchers
records.mongory
  .with_context(custom_option: true)
  .where(:status => 'active')
  .where(:age.gte => 18)
```

This will share a mutatable, but stable context object to all matchers in matcher tree.
To get your custom option, using `@context.config` in your custom matcher.

### Debugging Queries

You can use `explain` to visualize the matcher tree structure:
```ruby
records = [
  { name: 'John', age: 25, status: 'active' },
  { name: 'Jane', age: 30, status: 'inactive' }
]

query = records.mongory
  .where(:age.gte => 18)
  .any_of(
    { :status => 'active' },
    { :name.regex => /^J/ }
  )

query.explain
```
Output:
```
And: {"age"=>{"$gte"=>18}, "$or"=>[{"status"=>"active"}, {"name"=>{"$regex"=>/^J/}}]}
├─ Field: "age" to match: {"$gte"=>18}
│  └─ Gte: 18
└─ Or: [{"status"=>"active"}, {"name"=>{"$regex"=>/^J/}}]
   ├─ Field: "status" to match: "active"
   │  └─ Eq: "active"
   └─ Field: "name" to match: {"$regex"=>/^J/}
      └─ Regex: /^J/
```

This helps you understand how your query is being processed and can be useful for debugging complex conditions.

Or use the debugger for detailed matching process:
```ruby
# Enable debugging
Mongory.debugger.enable

# Execute your query
query = Mongory.build_query(users).where(age: { :$gt => 18 })
query.each do |user|
  puts user
end

# Display the debug trace
Mongory.debugger.display
```

The debug output will show detailed matching process with full class names:
```
QueryMatcher Matched, condition: {"age"=>{"$gt"=>18}}, record: {"age"=>25}
  AndMatcher Matched, condition: {"age"=>{"$gt"=>18}}, record: {"age"=>25}
    FieldMatcher Matched, condition: {"$gt"=>18}, field: "age", record: {"age"=>25}
      GtMatcher Matched, condition: 18, record: 25
```

The debug output includes:
- The matcher tree structure with full class names
- Each matcher's condition and record value
- Color-coded results (green for matched, red for mismatched, purple for errors)
- Field names highlighted in gray background
- Detailed matching process for each record

### Performance Considerations

1. **Memory Usage**
   - Mongory operates entirely in memory
   - Consider your data size and memory constraints
   - Proc-based implementation reduces memory usage
   - Context system provides better memory management

2. **Query Optimization**
   - Complex conditions are evaluated in sequence
   - Use `explain` to analyze query performance
   - Empty conditions are optimized with cached Procs
   - Context system allows fine-grained control over conversion

3. **Benchmarks**
  ```ruby
    # Simple query (1000 records)
    records.mongory.where(:age.gte => 18) # ~0.8ms

    # Complex query (1000 records)
    records.mongory.where(:$or => [{:age.gte => 18}, {:status => 'active'}]) # ~0.9ms

    # Simple query (10000 records)
    records.mongory.where(:age.gte => 18) # ~6.5ms

    # Complex query (10000 records)
    records.mongory.where(:$or => [{:age.gte => 18}, {:status => 'active'}]) # ~7.5ms

    # Simple query (100000 records)
    records.mongory.where(:age.gte => 18) # ~64.7ms

    # Complex query (100000 records)
    records.mongory.where(:$or => [{:age.gte => 18}, {:status => 'active'}]) # ~75.0ms

    # Complex query with fast mode (100000 records)
    records.mongory.where(:$or => [{:age.gte => 18}, {:status => 'active'}]).fast # ~42.8ms, about 3x of plain ruby
  ```

   Note: Performance varies based on:
   - Data size
   - Query complexity
   - Hardware specifications
   - Ruby version

   Test in your environment to determine if performance meets your needs.

### Supported Operators

| Category     | Operators                           |
|--------------|-------------------------------------|
| Comparison   | `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte` |
| Set          | `$in`, `$nin`                       |
| Boolean      | `$and`, `$or`, `$not`               |
| Pattern      | `$regex`                            |
| Presence     | `$exists`, `$present`               |
| Nested Match | `$elemMatch`, `$every`              |

Note: Some operators are Mongory-specific and not available in MongoDB:
- `$present`: Checks if a field is considered "present" (not nil, not empty, not KEY_NOT_FOUND)
  - Similar to `$exists` but evaluates truthiness of the value
  - Example: `where(:name.present => true)`
- `$every`: Checks if all elements in an array match the given condition
  - Similar to `$elemMatch` but requires all elements to match
  - Example: `where(:tags.every => { :priority.gt => 5 })`

Example:
```ruby
# $present: Check if field is present (not nil, not empty)
records.mongory.where(:name.present => true)  # name is present
records.mongory.where(:name.present => false) # name is not present

# $every: Check if all array elements match condition
records.mongory.where(:tags.every => { :priority.gt => 5 })  # all tags have priority > 5
```

## FAQ

### Q: How does Mongory compare to MongoDB?
A: Mongory provides similar query syntax but operates entirely in memory. It's ideal for:
- Small to medium datasets
- Complex in-memory filtering
- Testing MongoDB-like queries without a database

### Q: Can I use Mongory with large datasets?
A: Yes, but consider:
- Memory usage
- Query complexity
- Caching strategies
- Using `limit` early in the chain

### Q: How do I handle errors?
```ruby
begin
  result = records.mongory.where(invalid: :condition)
rescue Mongory::Error => e
  # Handle error
end
```

## Troubleshooting

1. **Debugging Queries**
   ```ruby
   Mongory.debugger.enable
   records.mongory.where(:age => 18).to_a
   Mongory.debugger.display
   Mongory.debugger.disable
   ```

2. **Common Issues**
   - Symbol snippets not working? Call `Mongory.enable_symbol_snippets!`
   - Complex queries slow? Use `explain` to analyze
   - Memory issues? Consider pagination or streaming

## Best Practices

1. **Query Composition**
   ```ruby
    # Good: Use method chaining
    records.mongory
      .where(:age.gte => 18)
      .where(:status => 'active')
      .limit(10)

    # Bad: Avoid redundant query creation
    query = records.mongory.where(:age.gte => 18)
    query = query.where(:status => 'active')  # Unnecessary
   ```

2. **Performance Tips**
   ```ruby
    # Use limit to restrict result set
    records.mongory.limit(100).where(:age.gte => 18)

    # Use fast mode for better performance
    records.mongory.where(:age.gte => 18).fast

    # Use explain to analyze complex queries
    query = records.mongory.where(:$or => [...])
    query.explain
   ```

3. **Code Organization**
   ```ruby
    # Encapsulate common queries as methods
    class User
      def active_adults
        friends.mongory
          .where(:age.gte => 18)
          .where(:status => 'active')
      end
    end
   ```

## Limitations

1. **Data Size**
   - Suitable for small to medium datasets
   - Large datasets may impact performance
   - Proc-based implementation helps with memory usage
   - Context system provides better resource management

2. **Query Complexity**
   - Complex queries may affect performance
   - Not all MongoDB operators are supported
   - Proc-based implementation improves complex query performance
   - Context system allows better control over query execution

3. **Memory Usage**
   - All operations are performed in memory
   - Consider memory constraints

## Migration Guide

1. **From Array#select**
  ```ruby
    # Before
    records.select { |r| r['age'] >= 18 && r['status'] == 'active' }

    # After
    records.mongory.where(:age.gte => 18, status: 'active')
  ```

2. **From ActiveRecord**
  ```ruby
    # Before
    indexed_query.where("age >= ? AND status = ?", 18, 'active')

    # After
    indexed_query.mongory.where(:age.gte => 18, status: 'active')
  ```

3. **From MongoDB**
  ```ruby
    # Before (MongoDB)
    users.where(:age.gte => 18, status: 'active')

    # After (Mongory)
    users.mongory.where(:age.gte => 18, status: 'active')

    # Just the same.
  ```

## Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**.
2. **Create a new branch** for each significant change.
3. **Write tests** for your changes.
4. **Send a pull request**.

Please ensure your code adheres to the project's style guide and that all tests pass before submitting.

## Code of Conduct

Everyone interacting in the Mongory-rb project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/mongoryhq/mongory-rb/blob/main/CODE_OF_CONDUCT.md).

## License

MIT. See LICENSE file.
