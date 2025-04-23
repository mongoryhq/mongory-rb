# frozen_string_literal: true

require_relative '../lib/mongory'
require 'benchmark'

# Register Array class
Mongory.register(Array)
Mongory.enable_symbol_snippets!

def gc_handler
  # GC.disable
  before = GC.stat
  yield
  after = GC.stat
  # GC.enable

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
      'age' => rand(1..100),
      'status' => ['active', 'inactive'].sample
    }
  end

  # Simple query (Plain Ruby) test
  puts "\nSimple query (Plain Ruby) (#{size} records):"
  gc_handler do
    5.times do
      result = Benchmark.measure do
        records.select { |r| r.key?('age') && r['age'] >= 18 }
      end
      puts result
    end
  end

  # Simple query (Mongory) test
  puts "\nSimple query (Mongory) (#{size} records):"
  gc_handler do
    5.times do
      result = Benchmark.measure do
        records.mongory.where(:age.gte => 18).to_a
      end
      puts result
    end
  end

  # Complex query (Plain Ruby) test
  puts "\nComplex query (Plain Ruby) (#{size} records):"
  gc_handler do
    5.times do
      result = Benchmark.measure do
        records.select do |r|
          next false unless r.key?('age') && r.key?('status')

          r['age'] >= 18 || r['status'] == 'active'
        end
      end
      puts result
    end
  end

  # Complex query (Mongory) test
  puts "\nComplex query (Mongory) (#{size} records):"
  gc_handler do
    5.times do
      result = Benchmark.measure do
        records.mongory.where(
          :$or => [
            { :age.gte => 18 },
            { status: 'active' }
          ]
        ).to_a
      end
      puts result
    end
  end

  # Complex query (Mongory) test
  puts "\nComplex query (Mongory) fast mode (#{size} records):"
  gc_handler do
    5.times do
      result = Benchmark.measure do
        records.mongory.where(
          :$or => [
            { :age.gte => 18 },
            { status: 'active' }
          ]
        ).fast.to_a
      end
      puts result
    end
  end
end
