# frozen_string_literal: true

require_relative '../lib/mongory'
require 'benchmark'

# Register Array class
Mongory.register(Array)
Mongory.enable_symbol_snippets!

# Test with different data sizes
[1000, 10_000, 100_000].each do |size|
  puts "\nTesting with #{size} records:"

  # Generate test data
  records = (1..size).map do |_|
    {
      'age' => rand(1..100),
      'status' => ['active', 'inactive'].sample
    }
  end

  # Simple query test
  puts "\nSimple query (#{size} records):"
  5.times do
    result = Benchmark.measure do
      records.mongory.where(:age.gte => 18).to_a
    end
    puts result
  end

  # Complex query test
  puts "\nComplex query (#{size} records):"
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
