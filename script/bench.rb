# frozen_string_literal: true

require_relative '../lib/mongory'

HAS_MONGOID = begin
  require 'mongoid'
  true
rescue LoadError
  false
end

Mongory.register(Array)
Mongory.enable_symbol_snippets!

N = 100_000
ROUNDS = 5

records = Array.new(N) do |i|
  {
    'age' => 10 + (i % 50),
    'status' => (i % 3).zero? ? 'active' : 'inactive',
    'name' => (i % 5).zero? ? "user#{'abcdef'[i % 6]}" : "other_#{i}",
    'tags' => (i % 4).zero? ? %w[ruby go] : %w[js c]
  }
end

LARGE_IN_TARGETS = ['usera', 'userb'] + Array.new(498) { |i| "other-#{i + 2}" }

puts "Ruby: #{RUBY_VERSION} (#{RUBY_PLATFORM}), records=#{N}, rounds=#{ROUNDS}, mongoid=#{HAS_MONGOID}"

def bench(label)
  # Warmup
  yield
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  count = 0
  ROUNDS.times { count = yield }
  elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0) / ROUNDS
  ns_per_rec = (elapsed_ms * 1_000_000.0) / N
  puts format(
    '%<label>-38s %<ms>8.2f ms / 100k  (%<ns>7.1f ns/rec, matched=%<count>d)',
    label: label,
    ms: elapsed_ms,
    ns: ns_per_rec,
    count: count
  )
end

if HAS_MONGOID
  class BenchDoc
    include Mongoid::Document
    field :age, type: Integer
    field :status, type: String
    field :name, type: String
    field :tags, type: Array
  end

  mongoid_docs = records.map { |r| BenchDoc.new(r) }
end

# 1. simple
bench('Plain Ruby (simple)') do
  records.count { |r| r['age'].is_a?(Numeric) && r['age'] >= 18 }
end

simple_m = Mongory::Matcher.new({ age: { :$gte => 18 } })
bench('Mongory::Matcher (simple)') do
  records.count { |r| simple_m.match?(r) }
end

if HAS_MONGOID
  simple_expr = { 'age' => { '$gte' => 18 } }
  bench('Mongoid::Matcher (simple)') do
    mongoid_docs.count { |d| d._matches?(simple_expr) }
  end
end

# 2. $or
bench('Plain Ruby ($or)') do
  records.count { |r| (r['age'].is_a?(Numeric) && r['age'] >= 18) || r['status'] == 'active' }
end

or_m = Mongory::Matcher.new({ :$or => [{ age: { :$gte => 18 } }, { status: 'active' }] })
bench('Mongory::Matcher ($or)') do
  records.count { |r| or_m.match?(r) }
end

if HAS_MONGOID
  or_expr = { '$or' => [{ 'age' => { '$gte' => 18 } }, { 'status' => 'active' }] }
  bench('Mongoid::Matcher ($or)') do
    mongoid_docs.count { |d| d._matches?(or_expr) }
  end
end

# 3. $in on array field
bench('Plain Ruby (in_array_field)') do
  records.count { |r| r['tags'].include?('ruby') || r['tags'].include?('rust') }
end

in_arr_m = Mongory::Matcher.new({ tags: { :$in => %w[ruby rust] } })
bench('Mongory::Matcher (in_array_field)') do
  records.count { |r| in_arr_m.match?(r) }
end

if HAS_MONGOID
  in_arr_expr = { 'tags' => { '$in' => %w[ruby rust] } }
  bench('Mongoid::Matcher (in_array_field)') do
    mongoid_docs.count { |d| d._matches?(in_arr_expr) }
  end
end

# 4. large $in (500 items)
large_in_set = LARGE_IN_TARGETS.each_with_object({}) { |k, h| h[k] = true }
bench('Plain Ruby (large_in_500)') do
  records.count { |r| large_in_set.key?(r['name']) }
end

large_in_m = Mongory::Matcher.new({ name: { :$in => LARGE_IN_TARGETS } })
bench('Mongory::Matcher (large_in_500)') do
  records.count { |r| large_in_m.match?(r) }
end

if HAS_MONGOID
  large_in_expr = { 'name' => { '$in' => LARGE_IN_TARGETS } }
  bench('Mongoid::Matcher (large_in_500)') do
    mongoid_docs.count { |d| d._matches?(large_in_expr) }
  end
end
