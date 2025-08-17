# Advanced Usage

## Complex Queries

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

## Integration with ActiveRecord

```ruby
class User < ActiveRecord::Base
  def active_friends
    friends.mongory
      .where(:status => 'active')
      .where(:last_seen.gte => 1.day.ago)
  end
end
```
