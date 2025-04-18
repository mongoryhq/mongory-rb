# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Converters::ConditionConverter do
  subject(:result) { described_class.instance.convert(input) }

  describe '#convert' do
    context 'when given a flat key-value condition' do
      let(:input) { { 'name' => 'Alice' } }

      it 'returns the same structure' do
        expect(result).to eq('name' => 'Alice')
      end
    end

    context 'when given a nested key with dot notation' do
      let(:input) { { 'user.name' => 'Frank' } }

      it 'converts it into nested hash structure' do
        expect(result).to eq('user' => { 'name' => 'Frank' })
      end
    end

    context 'when given multiple keys with shared prefix' do
      let(:input) { { 'user.name' => 'Frank', 'user.age' => 20 } }

      it 'merges them into a single nested hash' do
        expect(result).to eq('user' => { 'name' => 'Frank', 'age' => 20 })
      end
    end

    context 'when key is a symbol and value has operator' do
      let(:input) { { age: { gt: 18 } } }

      it 'normalizes key and value properly' do
        expect(result).to eq('age' => { 'gt' => 18 })
      end
    end

    context 'when using symbol operator chaining syntax' do
      let(:input) { { :age.gt => 30 } }

      it 'converts using QueryOperator chaining' do
        expect(result).to eq('age' => { '$gt' => 30 })
      end
    end

    context 'when structure is deeply nested' do
      let(:input) { { 'a.b.c' => { in: [1, 2] } } }

      it 'produces a deeply nested hash with normalized operator' do
        expect(result).to eq('a' => { 'b' => { 'c' => { 'in' => [1, 2] } } })
      end
    end
  end
end
