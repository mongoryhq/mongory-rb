# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::HashConditionMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }
    let(:condition) { {} }

    it_behaves_like 'all the sub-matchers of multi matcher has the same context'
    context 'when condition is a single field matcher' do
      let(:condition) { { 'x' => 1 } }

      it { is_expected.to be_match('x' => 1) }
      it { is_expected.not_to be_match('x' => 2) }
      it { is_expected.not_to be_match({}) }
    end

    context 'when condition is a single operator matcher' do
      let(:condition) { { '$gt' => 5 } }

      it { is_expected.to be_match(10) }
      it { is_expected.not_to be_match(3) }
    end

    context 'when condition is mixed: field + operator' do
      let(:condition) { { 'x' => { '$gt' => 10 }, '$exists' => true } }

      it_behaves_like 'all the sub-matchers of multi matcher has the same context'
      it { is_expected.to be_match('x' => 20) }
      it { is_expected.not_to be_match('x' => 5) }
      it { is_expected.not_to be_match({}) }
    end

    context 'when all subconditions must match' do
      let(:condition) { { 'x' => { '$gt' => 10 }, 'y' => 1 } }

      it_behaves_like 'all the sub-matchers of multi matcher has the same context'
      it { is_expected.to be_match('x' => 20, 'y' => 1) }
      it { is_expected.not_to be_match('x' => 5, 'y' => 1) }
      it { is_expected.not_to be_match('x' => 20, 'y' => 2) }
    end

    context 'when condition has $regex with $options' do
      let(:condition) { { '$regex' => '^ab', '$options' => 'is' } }

      it { is_expected.to be_match('ABC') }
      it { is_expected.not_to be_match('xab') }
    end
  end

  describe 'condition validation' do
    subject(:build) { described_class.new(condition) }

    context 'when an operator is unknown' do
      let(:condition) { { 'x' => { '$foo' => 1 } } }

      it { expect { build }.to raise_error(Mongory::TypeError, /unknown operator \$foo/) }
    end

    context 'when an unknown operator is nested in $elemMatch' do
      let(:condition) { { 'xs' => { '$elemMatch' => { '$foo' => 1 } } } }

      it { expect { build }.to raise_error(Mongory::TypeError, /unknown operator/) }
    end

    context 'when $options has no sibling $regex' do
      let(:condition) { { 'x' => { '$options' => 'i' } } }

      it { expect { build }.to raise_error(Mongory::TypeError, /\$options needs a sibling \$regex/) }
    end

    context 'when a key only contains $ after the first character' do
      let(:condition) { { 'price$' => 1 } }

      it { is_expected.to be_match('price$' => 1) }
    end
  end

  describe '#priority with lazy ArrayRecordMatcher' do
    it 'updates field and root priorities once array fields are matched' do
      condition = {
        'scores' => { '$size' => { '$gte' => 3, '$lte' => 5 }, '$every' => { '$gte' => 60 } },
        'tags' => 'ts',
        'reviews' => { 'approved' => true, 'rating' => { '$gte' => 4 } }
      }
      matcher = described_class.build(condition)
      before_root = matcher.priority
      before_children = matcher.matchers.map(&:priority)

      record = {
        'candidate' => 'Alice',
        'tags' => %w[go ts rust],
        'scores' => [82, 91, 77],
        'reviews' => [
          { 'reviewer' => 'r1', 'approved' => false, 'rating' => 5 },
          { 'reviewer' => 'r2', 'approved' => true, 'rating' => 5 },
          { 'reviewer' => 'r3', 'approved' => true, 'rating' => 4 }
        ]
      }
      expect(matcher).to be_match(record)

      after_children = matcher.matchers.map(&:priority)
      expect(after_children[0]).to be > before_children[0]
      expect(after_children[1]).to be > before_children[1]
      expect(matcher.priority).to eq(1 + after_children.sum)
      expect(matcher.priority).to be > before_root
    end

    def track_fetches(hash)
      visited = []
      klass = Class.new(Hash) do
        define_method(:fetch) do |key, *args, &block|
          visited << key
          super(key, *args, &block)
        end
      end
      [klass[hash], visited]
    end

    it 're-sorts sibling matchers and rebuilds procs after lazy ArrayRecordMatcher build' do
      condition = {
        'tags' => 'ts',
        'age' => { '$gte' => 18 },
        'items' => { '$size' => { '$gte' => 1 } }
      }
      matcher = described_class.build(condition)
      expect(matcher.matchers.map { |m| m.instance_variable_get(:@field) }).to eq(%w[tags age items])

      rec1, visited1 = track_fetches('tags' => %w[go ts], 'age' => 20, 'items' => %w[x])
      expect(matcher).to be_match(rec1)
      expect(visited1).to eq(%w[tags age items])

      expect(matcher.matchers.map { |m| m.instance_variable_get(:@field) }).to eq(%w[age tags items])

      rec2, visited2 = track_fetches('tags' => %w[ts], 'age' => 10, 'items' => %w[x])
      expect(matcher).not_to be_match(rec2)
      expect(visited2).to eq(%w[age])
    end

    it 're-sorts OrMatcher and QueryMatcher children across nested array and $not wrappers' do
      or_matcher = Mongory::Matchers::OrMatcher.build([
        { 'tags' => 'ts' },
        { 'age' => { '$gte' => 18 } }
      ])
      rec_or1, visited_or1 = track_fetches('tags' => %w[go ts], 'age' => 10)
      expect(or_matcher).to be_match(rec_or1)
      expect(visited_or1).to eq(%w[tags])
      expect(or_matcher.matchers.map { |m| m.instance_variable_get(:@field) }).to eq(%w[age tags])

      rec_or2, visited_or2 = track_fetches('tags' => %w[ts], 'age' => 25)
      expect(or_matcher).to be_match(rec_or2)
      expect(visited_or2).to eq(%w[age])

      query_cond = {
        'matrix' => { 'tags' => { '$not' => 'bad' } },
        'score' => { '$gte' => 0, '$lte' => 100 }
      }
      query = Mongory::QueryMatcher.new(query_cond)
      query.prepare_query
      expect(query.matchers.map { |m| m.instance_variable_get(:@field) }).to eq(%w[matrix score])

      expect(query).to be_match('matrix' => [{ 'tags' => %w[good] }], 'score' => 50)
      expect(query.matchers.map { |m| m.instance_variable_get(:@field) }).to eq(%w[score matrix])

      rec_q2, visited_q2 = track_fetches('matrix' => [{ 'tags' => %w[good] }], 'score' => 200)
      expect(query).not_to be_match(rec_q2)
      expect(visited_q2).to eq(%w[score])
    end
  end
end
