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

# Implicit array element & index queries (MongoDB-compatible)
posts.mongory
  .where(:scores.gt => 80)           # Matches if any score > 80
  .where(:tags.ne => 'archived')     # Matches if no tag is 'archived'
  .where('tags.0' => 'ruby')         # Matches if first tag is 'ruby'
  .where('tags.-1' => 'featured')    # Matches if last tag is 'featured'

# Since Matcher provide `to_proc` method, you could treat Matcher as a block
matcher = Mongory::QueryMatcher.new({
  :tags.elem_match => { :name => 'ruby', :priority.gt => 5 },
  :comments.every => { :approved => true }
})

# Will filter
posts_1.select!(&matcher)
posts_2.select!(&matcher)
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
