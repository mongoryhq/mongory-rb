# Performance & Benchmarks

## C Extension vs Pure Ruby

- C extension provides 3-10x performance improvement for large datasets
- Automatic fallback to pure Ruby if C extension unavailable
- Check availability: `defined?(Mongory::CMatcher)` or attempt to require the extension
- Memory management handled by mongory-core's memory pool

## Memory Usage

- Mongory operates entirely in memory
- Consider your data size and memory constraints
- Proc-based implementation reduces memory usage
- Context system provides better memory management

## Query Optimization

- Complex conditions are evaluated in sequence
- Use `explain` to analyze query performance
- Empty conditions are optimized with cached Procs
- Context system allows fine-grained control over conversion

## Benchmarks

```ruby
  # Plain Ruby Simple query (100000 records)
  records.select { |r| r['age'].is_a?(Numeric) && r['age'] >= 18 } # ~9ms

  # Plain Ruby Complex query (100000 records)
  records.select do |r|
    next false unless r.key?('age') && r.key?('status')

    r['age'].is_a?(Numeric) && r['age'] >= 18 ||  r['status'] == 'active'
  end # ~20ms

  # Simple query (100000 records)
  records.mongory.where(:age.gte => 18) # ~119ms

  # Complex query (100000 records)
  records.mongory.where(:$or => [{:age.gte => 18}, {:status => 'active'}]) # ~107ms

  # Complex query with fast mode (100000 records)
  records.mongory.where(:$or => [{:age.gte => 18}, {:status => 'active'}]).fast # ~63ms

  # Simple query with C extension (100000 records)
  records.mongory.c.where(:age.gte => 18) # ~15ms
  # Complex query with C extension (100000 records)
  records.mongory.c.where(:$or => [{:age.gte => 18}, {:status => 'active'}]) # ~23ms, same with plain ruby
```

Note: Performance varies based on:

- Data size
- Query complexity
- Hardware specifications
- Ruby version

Benchmark in your environment to validate.


