# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mongory fuzzing' do
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

    case rng.rand(6)
    when 0, 1, 2
      { pick(rng, %w($and $or $nor)) => Array.new(rng.rand(1..3)) { random_valid_condition(rng, depth - 1) } }
    when 3
      { 'tags' => { pick(rng, %w($elemMatch $every)) => random_valid_op_hash(rng) } }
    else
      random_field_map(rng)
    end
  end

  def random_hostile_condition(rng, depth)
    return random_scalar(rng) if depth <= 0

    ops = %w($eq $ne $gt $in $nin $and $or $nor $not $elemMatch $every $size $exists $present $regex $unknown a age)
    rng.rand(0..3).times.each_with_object({}) do |_, h|
      key = pick(rng, ops)
      h[key] = rng.rand(3).zero? ? random_hostile_condition(rng, depth - 1) : random_scalar(rng)
    end
  end

  it 'keeps match? and trace_tree consistent across randomized valid queries' do
    rng = Random.new(seed)
    iterations.times do |i|
      cond = random_valid_condition(rng, 2)
      matcher = Mongory::Matcher.new(cond)

      expect(matcher.explain_tree).to be_a(Hash)

      2.times do
        rec = random_record(rng)
        res = matcher.match?(rec)
        trace = matcher.trace_tree(rec)
        expected = res ? :pass : :fail
        expect(trace[:result]).to eq(expected), "iter=#{i} cond=#{cond.inspect} rec=#{rec.inspect}"
      end

      GC.start if (i % 250).zero?
    end
  end

  it 'never crashes on hostile randomized conditions in Matcher' do
    rng = Random.new(seed + 1)
    (iterations / 2).times do
      cond = random_hostile_condition(rng, 2)
      rec = random_record(rng)

      begin
        matcher = Mongory::Matcher.new(cond)
        matcher.match?(rec)
        matcher.explain_tree
        matcher.trace_tree(rec)
      rescue Mongory::Error
        nil
      end
    end
  end
end
