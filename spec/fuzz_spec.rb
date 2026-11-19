# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mongory differential fuzzing' do
  let(:iterations) { Integer(ENV.fetch('FUZZ_ITERATIONS', '1000')) }
  let(:seed) { Integer(ENV.fetch('FUZZ_SEED', '1367130551')) }

  def pick(rng, list)
    list[rng.rand(list.length)]
  end

  def random_scalar(rng)
    pick(rng, [nil, true, false, 0, 1, -1, 18, 40, 3.5, '', 'active', 'inactive', 'go', 'ruby', 'c'])
  end

  def random_record(rng)
    {
      'a' => random_scalar(rng),
      'b' => pick(rng, [random_scalar(rng), [1, 2, 18], { 'c' => random_scalar(rng) }]),
      'age' => pick(rng, [10, 18, 25, '18', nil, [15, 25]]),
      'status' => pick(rng, ['active', 'inactive', nil, ['active']]),
      'tags' => pick(rng, [%w(go ruby), [], 'go', [{ '01' => 'c' }, { '-0' => 'ruby' }]]),
      'profile' => pick(rng, [{ 'city' => 'taipei' }, nil, 'scalar', [{ 'city' => 'tokyo' }]])
    }
  end

  def random_valid_op_hash(rng)
    case rng.rand(9)
    when 0 then { '$eq' => random_scalar(rng) }
    when 1 then { '$ne' => random_scalar(rng) }
    when 2 then { pick(rng, %w($gt $gte $lt $lte)) => pick(rng, [0, 18, 40, 3.5, 'a', 'z']) }
    when 3 then { pick(rng, %w($in $nin)) => Array.new(rng.rand(4)) { random_scalar(rng) } }
    when 4 then { '$exists' => pick(rng, [true, false]) }
    when 5 then { '$present' => pick(rng, [true, false]) }
    when 6 then { '$size' => rng.rand(4) }
    when 7 then { '$regex' => pick(rng, ['^act', 'go|ruby', '[0-9]+']) }
    else { '$not' => { '$eq' => random_scalar(rng) } }
    end
  end

  def random_valid_leaf_cond(rng)
    rng.rand(5).zero? ? random_scalar(rng) : random_valid_op_hash(rng)
  end

  def random_field_map(rng)
    keys = %w(a b age status tags profile.city tags.0 tags.-1 tags.01 tags.-0)
    rng.rand(1..3).times.each_with_object({}) do |_, h|
      h[pick(rng, keys)] = random_valid_leaf_cond(rng)
    end
  end

  def random_valid_condition(rng, depth)
    return { pick(rng, %w(a age status tags profile.city)) => random_valid_leaf_cond(rng) } if depth <= 0

    case rng.rand(5)
    when 0
      { '$and' => Array.new(rng.rand(1..3)) { random_valid_condition(rng, depth - 1) } }
    when 1
      { '$or' => Array.new(rng.rand(1..3)) { random_valid_condition(rng, depth - 1) } }
    when 2
      { 'tags' => { pick(rng, %w($elemMatch $every)) => random_valid_op_hash(rng) } }
    else
      random_field_map(rng)
    end
  end

  def random_hostile_condition(rng, depth)
    return random_scalar(rng) if depth <= 0

    ops = %w($eq $ne $gt $in $nin $and $or $not $elemMatch $every $size $exists $present $regex $unknown a age)
    rng.rand(0..3).times.each_with_object({}) do |_, h|
      key = pick(rng, ops)
      h[key] = rng.rand(3).zero? ? random_hostile_condition(rng, depth - 1) : random_scalar(rng)
    end
  end

  it 'keeps QueryMatcher and CMatcher in differential parity across randomized valid queries' do
    skip 'CMatcher not available' unless defined?(Mongory::CMatcher)

    rng = Random.new(seed)
    iterations.times do |i|
      cond = random_valid_condition(rng, 2)
      rb_matcher = Mongory::QueryMatcher.new(cond)
      rb_matcher.prepare_query
      c_matcher = Mongory::CMatcher.new(cond)

      expect(rb_matcher.explain_tree).to be_a(Hash)
      expect(c_matcher.explain_tree).to be_a(Hash)

      2.times do
        rec = random_record(rng)
        rb_res = rb_matcher.match?(rec)
        c_res = c_matcher.match?(rec)
        expect(c_res).to eq(rb_res), "iter=#{i} cond=#{cond.inspect} rec=#{rec.inspect} rb=#{rb_res} c=#{c_res}"

        rb_trace = rb_matcher.trace_tree(rec)
        c_trace = c_matcher.trace_tree(rec)
        expected = rb_res ? :pass : :fail
        expect(rb_trace[:result]).to eq(expected), "iter=#{i} rb trace mismatch"
        expect(c_trace[:result]).to eq(expected), "iter=#{i} c trace mismatch"
      end

      GC.start if (i % 250).zero?
    end
  end

  it 'never crashes on hostile randomized conditions in QueryMatcher or CMatcher' do
    skip 'CMatcher not available' unless defined?(Mongory::CMatcher)

    rng = Random.new(seed + 1)
    (iterations / 2).times do
      cond = random_hostile_condition(rng, 2)
      rec = random_record(rng)

      [Mongory::QueryMatcher, Mongory::CMatcher].each do |klass|
        matcher = klass.new(cond)
        matcher.prepare_query if matcher.respond_to?(:prepare_query)
        matcher.match?(rec)
        matcher.explain_tree
        matcher.trace_tree(rec)
      rescue Mongory::Error
        nil
      end
    end
  end
end
