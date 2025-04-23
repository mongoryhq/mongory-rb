# frozen_string_literal: true

require 'active_support/all'
require 'benchmark'

puts 'Ruby String#empty?'
result = Benchmark.measure do
  1_000_000.times do
    ''.empty?
  end
end
puts result

puts 'Rails String#blank?'
result = Benchmark.measure do
  1_000_000.times do
    ''.blank?
  end
end
puts result

puts 'Ruby Array#empty?'
result = Benchmark.measure do
  1_000_000.times do
    [].empty?
  end
end
puts result

puts 'Rails Array#blank?'
result = Benchmark.measure do
  1_000_000.times do
    [].blank?
  end
end
puts result

puts 'Ruby Hash#empty?'
result = Benchmark.measure do
  1_000_000.times do
    {}.empty?
  end
end
puts result

puts 'Rails Hash#blank?'
result = Benchmark.measure do
  1_000_000.times do
    {}.blank?
  end
end
puts result
