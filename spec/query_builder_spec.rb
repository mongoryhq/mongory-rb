# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::QueryBuilder do
  describe 'method chaining' do
    subject do
      described_class
        .new(records)
        .where(:tags.in => ['ruby', 'qa'])
        .and(:age.gte => 25)
        .any_of({ name: /e/ }, { :tags.present => true })
        .limit(3)
        .pluck(:name)
    end

    let(:records) do
      [
        { name: 'Alice', age: 30, tags: ['ruby'] },
        { name: 'Bob', age: 25, tags: ['qa'] },
        { name: 'Carol', age: 35, tags: ['ruby'] },
        { name: 'Dave', age: 20, tags: ['js'] },
        { name: 'Eve', age: 32, tags: ['qa'] }
      ]
    end

    it 'returns expected chained result' do
      expect(subject).to eq(['Alice', 'Bob', 'Carol'])
    end
  end

  describe '#each' do
    subject { described_class.new(records).where(:age.gt => 28) }
    let(:records) do
      [
        { name: 'Alice', age: 30 },
        { name: 'Bob', age: 25 },
        { name: 'Carol', age: 35 }
      ]
    end

    it 'is enumerable' do
      names = []
      subject.each { |r| names << r[:name] }
      expect(names).to contain_exactly('Alice', 'Carol')
      expect(names).not_to be_include('Bob')
    end

    it 'returns an enumerator when no block given' do
      enumerator = subject.each
      expect(enumerator).to be_a(Enumerator)
      names = enumerator.map { |x| x[:name] }
      expect(names).to contain_exactly('Alice', 'Carol')
      expect(names).not_to contain_exactly('Bob')
    end
  end

  describe '#where' do
    subject { described_class.new(records).where(condition) }

    let(:records) do
      [
        { 'name' => 'Alice', 'age' => 30, 'tags' => ['ruby', 'dev'] },
        { 'name' => 'Bob', 'age' => 25, 'tags' => ['js', 'qa'] },
        { 'name' => 'Carol', 'age' => 35, 'tags' => ['ruby', 'qa'] }
      ]
    end

    context 'when filtering by gt condition' do
      let(:condition) { { :age.gt => 28 } }

      it { is_expected.to contain_exactly(include('name' => 'Alice'), include('name' => 'Carol')) }
      it { is_expected.not_to contain_exactly(include('name' => 'Bob')) }
    end

    context 'when filtering by equality' do
      let(:condition) { { name: 'Bob' } }

      it { is_expected.to contain_exactly(include('name' => 'Bob')) }
      it { is_expected.not_to contain_exactly(include('name' => 'Alice'), include('name' => 'Carol')) }
    end

    context 'when filtering by in operator' do
      let(:condition) { { :tags.in => ['ruby'] } }

      it { is_expected.to contain_exactly(include('name' => 'Alice'), include('name' => 'Carol')) }
    end

    context 'when filtering by multiple fields' do
      let(:condition) { { name: 'Carol', :age.gt => 30 } }

      it { is_expected.to contain_exactly(include('name' => 'Carol')) }
    end

    context 'when filtering by nested or condition' do
      let(:condition) { { '$or': [{ name: 'Bob' }, { :age.gt => 32 }] } }

      it { is_expected.to contain_exactly(include('name' => 'Bob'), include('name' => 'Carol')) }
    end
  end

  describe '#and' do
    subject { described_class.new(records).and(*conditions) }

    let(:records) do
      [
        { 'name' => 'Alice', 'age' => 30, 'tags' => ['ruby', 'dev'] },
        { 'name' => 'Bob', 'age' => 25, 'tags' => ['js', 'qa'] },
        { 'name' => 'Carol', 'age' => 35, 'tags' => ['ruby', 'qa'] },
        { 'name' => 'Dave', 'age' => 20, 'tags' => [] }
      ]
    end

    context 'when all conditions match a single record' do
      let(:conditions) { [{ :tags.in => ['ruby'] }, { :age.gt => 30 }] }

      it { is_expected.to contain_exactly(include('name' => 'Carol')) }
    end

    context 'when only one condition matches' do
      let(:conditions) { [{ :tags.in => ['ruby'] }, { :age.lt => 25 }] }

      it { expect(subject.count).to eq 0 }
    end

    context 'when no condition matches' do
      let(:conditions) { [{ name: 'Zoe' }, { :age.gt => 100 }] }

      it { expect(subject.count).to eq 0 }
    end

    context 'when combining equality and operator condition' do
      let(:conditions) { [{ name: 'Bob' }, { :age.lt => 30 }] }

      it { is_expected.to contain_exactly(include('name' => 'Bob')) }
    end

    context 'when conditions are deeply nested' do
      let(:conditions) do
        [
          { '$and': [
            { :tags.in => ['ruby'] },
            { '$or': [{ :age.lte => 30 }, { name: 'Carol' }] }
          ] }
        ]
      end

      it { is_expected.to contain_exactly(include('name' => 'Alice'), include('name' => 'Carol')) }
    end
  end

  describe '#or' do
    subject { described_class.new(records).or(*conditions) }
    let(:records) do
      [
        { 'name' => 'Alice', 'age' => 30, 'tags' => ['ruby', 'dev'] },
        { 'name' => 'Bob', 'age' => 25, 'tags' => ['js', 'qa'] },
        { 'name' => 'Carol', 'age' => 35, 'tags' => ['ruby', 'qa'] },
        { 'name' => 'Dave', 'age' => 20, 'tags' => [] }
      ]
    end

    context 'when any condition matches (simple or)' do
      let(:conditions) { [{ name: 'Bob' }, { :age.gt => 32 }] }

      it { is_expected.to contain_exactly(include('name' => 'Bob'), include('name' => 'Carol')) }
    end

    context 'when multiple conditions match same record' do
      let(:conditions) { [{ :tags.in => ['ruby'] }, { name: 'Carol' }] }

      it { is_expected.to contain_exactly(include('name' => 'Alice'), include('name' => 'Carol')) }
    end

    context 'when only one condition matches one record' do
      let(:conditions) { [{ name: 'Zoe' }, { :age.lte => 20 }] }

      it { is_expected.to contain_exactly(include('name' => 'Dave')) }
    end

    context 'when no condition matches' do
      let(:conditions) { [{ name: 'Zoe' }, { :tags.in => ['java'] }] }

      it { expect(subject.count).to eq 0 }
    end

    context 'when nested or is used inside' do
      let(:conditions) do
        [
          { '$or': [
            { name: 'Alice' },
            { :tags.in => ['qa'] }
          ] }
        ]
      end

      it do
        is_expected.to contain_exactly(
          include('name' => 'Alice'),
          include('name' => 'Bob'),
          include('name' => 'Carol')
        )
      end
    end
  end

  describe '#not' do
    subject { described_class.new(records).not(condition) }
    let(:records) do
      [
        { 'name' => 'Alice', 'age' => 30, 'tags' => ['ruby', 'dev'] },
        { 'name' => 'Bob', 'age' => 25, 'tags' => ['js', 'qa'] },
        { 'name' => 'Carol', 'age' => 35, 'tags' => ['ruby', 'qa'] },
        { 'name' => 'Dave', 'age' => 20, 'tags' => [] }
      ]
    end

    context 'when negating a simple equality condition' do
      let(:condition) { { name: 'Alice' } }

      it do
        is_expected.to contain_exactly(
          include('name' => 'Bob'),
          include('name' => 'Carol'),
          include('name' => 'Dave')
        )
        is_expected.not_to contain_exactly(include('name' => 'Alice'))
      end
    end

    context 'when negating a single operator condition' do
      let(:condition) { { :age.gt => 30 } }

      it do
        is_expected.to contain_exactly(
          include('name' => 'Alice'),
          include('name' => 'Bob'),
          include('name' => 'Dave')
        )
      end
    end

    context 'when negating an in operator' do
      let(:condition) { { :tags.in => ['ruby'] } }

      it do
        is_expected.to contain_exactly(
          include('name' => 'Bob'),
          include('name' => 'Dave')
        )
      end
    end

    context 'when condition excludes all' do
      let(:condition) { { :age.lte => 100 } }

      it { expect(subject.count).to eq 0 }
    end

    context 'when condition matches none' do
      let(:condition) { { name: 'Zoe' } }

      it do
        is_expected.to contain_exactly(
          include('name' => 'Alice'),
          include('name' => 'Bob'),
          include('name' => 'Carol'),
          include('name' => 'Dave')
        )
      end
    end
  end

  describe '#limit' do
    subject { described_class.new(records).limit(limit_size) }
    let(:records) do
      [
        { 'name' => 'Alice', 'age' => 30 },
        { 'name' => 'Bob', 'age' => 25 },
        { 'name' => 'Carol', 'age' => 35 },
        { 'name' => 'Dave', 'age' => 20 }
      ]
    end

    context 'when limit is 2' do
      let(:limit_size) { 2 }

      it 'returns only 2 records' do
        expect(subject.count).to eq 2
      end
    end

    context 'when limit is 0' do
      let(:limit_size) { 0 }

      it 'returns an empty result' do
        expect(subject.count).to eq 0
      end
    end

    context 'when limit is greater than total records' do
      let(:limit_size) { 10 }

      it 'returns all records' do
        expect(subject.count).to eq 4
      end
    end
  end

  describe '#pluck' do
    subject { described_class.new(records).pluck(*fields) }
    let(:records) do
      [
        { name: 'Alice', age: 30 },
        { name: 'Bob', age: 25 },
        { name: 'Carol', age: 35 },
        { name: 'Dave', age: 20 }
      ]
    end

    context 'when extracting one field' do
      let(:fields) { [:name] }

      it { is_expected.to eq(['Alice', 'Bob', 'Carol', 'Dave']) }
    end

    context 'when extracting multiple fields' do
      let(:fields) { [:name, :age] }

      it do
        is_expected.to eq([
          ['Alice', 30],
          ['Bob', 25],
          ['Carol', 35],
          ['Dave', 20]
        ])
      end
    end

    context 'when field is missing in some records' do
      let(:records) do
        [
          { name: 'Alice', age: 30 },
          { name: 'Bob' },
          { name: 'Carol', age: 35 }
        ]
      end

      let(:fields) { [:name, :age] }

      it do
        is_expected.to eq([
          ['Alice', 30],
          ['Bob', nil],
          ['Carol', 35]
        ])
      end
    end
  end
end
