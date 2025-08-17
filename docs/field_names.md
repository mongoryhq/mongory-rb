# Handling Dots in Field Names

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

Notes:
- With double quotes, backslashes need to be escaped (`\\`)
- With single quotes, backslashes don't need to be escaped (`\`)
- This behavior is consistent with MongoDB's query syntax
- The escaped dot pattern (`\.`) matches fields where the dot is part of the field name
- The unescaped dot pattern (`.`) matches nested fields in the document structure
