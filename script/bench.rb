# frozen_string_literal: true

require 'benchmark'
require_relative '../lib/mongory'

Mongory.register(Array)
Mongory.enable_symbol_snippets!

N = 100_000
ROUNDS = 5

records = Array.new(N) do |i|
  {
    'age' => 10 + (i % 50),
    'status' => (i % 3).zero? ? 'active' : 'inactive'
  }
end

puts "Ruby: #{RUBY_VERSION} (#{RUBY_PLATFORM}), records=#{N}, rounds=#{ROUNDS}"

def bench(label)
  # Warmup
  yield
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  count = 0
  ROUNDS.times { count = yield }
  elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0) / ROUNDS
  ns_per_rec = (elapsed_ms * 1_000_000.0) / N
  puts format(
    '%<label>-34s %<ms>8.2f ms / 100k  (%<ns>6.1f ns/rec, matched=%<count>d)',
    label: label,
    ms: elapsed_ms,
    ns: ns_per_rec,
    count: count
  )
end

bench('Plain Ruby (simple)') do
  records.count { |r| r['age'].is_a?(Numeric) && r['age'] >= 18 }
end

simple_m = Mongory::Matcher.new({ age: { :$gte => 18 } })
bench('Mongory::Matcher (simple)') do
  records.count { |r| simple_m.match?(r) }
end

bench('Plain Ruby ($or)') do
  records.count { |r| (r['age'].is_a?(Numeric) && r['age'] >= 18) || r['status'] == 'active' }
end

or_m = Mongory::Matcher.new({ :$or => [{ age: { :$gte => 18 } }, { status: 'active' }] })
bench('Mongory::Matcher ($or)') do
  records.count { |r| or_m.match?(r) }
end
