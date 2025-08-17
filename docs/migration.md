# Migration Guide

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
