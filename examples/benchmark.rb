# frozen_string_literal: true

require_relative '../lib/mongory'
require 'benchmark'

# Register Array class
Mongory.register(Array)
Mongory.enable_symbol_snippets!

def gc_handler
  GC.disable
  before = GC.stat
  yield
  GC.start
  after = GC.stat
  GC.enable
  created = after[:total_allocated_objects] - before[:total_allocated_objects]
  freed   = after[:total_freed_objects] - before[:total_freed_objects]
  alive   = after[:heap_live_slots] - before[:heap_live_slots]

  puts "Created: #{created}"    # 分配了幾個 object
  puts "Freed: #{freed}"        # 中途 GC 掃掉幾個（若 GC 有觸發）
  puts "Net alive: #{alive}"    # 最後還活著的物件數
end
# Test with different data sizes
[20, 1000, 10_000, 100_000].each do |size|
  puts "\nTesting with #{size} records:"

  # Generate test data
  records = (1..size).map do |_|
    {
      'age' => [nil, rand(1..100)].sample,
      'status' => ['active', 'inactive'].sample
    }
  end

  count_of_simple_query = records.count { |r| r['age'].is_a?(Numeric) && r['age'] >= 18 }
  # Simple query (Plain Ruby) test
  puts "\nSimple query (Plain Ruby) (#{size} records):"
  gc_handler do
    5.times do
      result = Benchmark.measure do
        records.select { |r| r['age'].is_a?(Numeric) && r['age'] >= 18 }
      end
      puts result
    end
  end

  # Simple query (Mongory) test
  puts "\nSimple query (Mongory) (#{size} records):"
  gc_handler do
    builder = records.mongory.where(:age.gte => 18)
    5.times do
      result = Benchmark.measure do
        builder.to_a
      end
      puts result
    end
    raise "count mismatch" if builder.to_a.count != count_of_simple_query
  end

  # Simple query (Mongory::CMatcher) test
  puts "\nSimple query (Mongory::CMatcher) (#{size} records):"
  gc_handler do
    matcher = Mongory::CMatcher.new(:age.gte => 18)
    5.times do
      result = Benchmark.measure do
        records.select { |r| matcher.match?(r) }
      end
      puts result
    end
    raise "count mismatch" if records.count { |r| matcher.match?(r) } != count_of_simple_query
  end

  # Simple query (Mongory::CQueryBuilder) test
  puts "\nSimple query (Mongory::CQueryBuilder) (#{size} records):"
  gc_handler do
    builder = Mongory::CQueryBuilder.new(records).where(:age.gte => 18)
    5.times do
      result = Benchmark.measure do
        builder.to_a
      end
      puts result
    end
    raise "count mismatch" if builder.count != count_of_simple_query
  end

  # Complex query (Plain Ruby) test
  puts "\nComplex query (Plain Ruby) (#{size} records):"
  gc_handler do
    5.times do
      result = Benchmark.measure do
        records.select do |r|
          next false unless r.key?('age') && r.key?('status')

          r['age'].is_a?(Numeric) && r['age'] >= 18 ||  r['status'] == 'active'
        end
      end
      puts result
    end
  end

  count_of_complex_query = records.count do |r|
    r.key?('age') && r.key?('status') && (r['age'].is_a?(Numeric) && r['age'] >= 18 || r['status'] == 'active')
  end

  # Complex query (Mongory) test
  puts "\nComplex query (Mongory) (#{size} records):"
  gc_handler do
    builder = records.mongory.or(
      { :age.gte => 18 },
      { status: 'active' }
    )
    5.times do
      result = Benchmark.measure do
        builder.to_a
      end
      puts result
    end
    raise "count mismatch" if builder.count != count_of_complex_query
  end

  # Complex query (Mongory) test
  puts "\nComplex query (Mongory) fast mode (#{size} records):"
  gc_handler do
    builder = records.mongory.or(
      { :age.gte => 18 },
      { status: 'active' }
    ).fast
    5.times do
      result = Benchmark.measure do
        builder.to_a
      end
      puts result
    end
    raise "count mismatch" if builder.count != count_of_complex_query
  end

  puts "\nComplex query (Mongory) use CMatcher (#{size} records):"
  gc_handler do
    matcher = Mongory::CMatcher.new(
      '$or' => [
        { :age.gte => 18 },
        { status: 'active' }
      ]
    )
    5.times do
      result = Benchmark.measure do
        records.select { |r| matcher.match?(r) }
      end
      puts result
    end
    raise "count mismatch" if records.count { |r| matcher.match?(r) } != count_of_complex_query
  end

  puts "\nComplex query (Mongory) use CQueryBuilder (#{size} records):"
  gc_handler do
    builder = records.mongory.c.or(
      { :age.gte => 18 },
      { status: 'active' }
    )
    5.times do
      result = Benchmark.measure do
        builder.to_a
      end
      puts result
    end
    raise "count mismatch" if builder.count != count_of_complex_query
  end

  puts "\nTest Mongory::CMatcher#trace"
  matcher = Mongory::CMatcher.new(
    '$or' => [
      { :age.gte => 18 },
      { status: 'active' }
    ]
  )
  # matcher.enable_trace
  records.sample(30).each do |r|
    matcher.trace(r)
  end
  # matcher.print_trace
  # matcher.disable_trace
end
