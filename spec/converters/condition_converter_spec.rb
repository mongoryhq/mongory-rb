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

      it 'preserves dotted key for mongory-core to expand' do
        expect(result).to eq('user.name' => 'Frank')
      end
    end

    context 'when given multiple keys with shared prefix' do
      let(:input) { { 'user.name' => 'Frank', 'user.age' => 20 } }

      it 'preserves both dotted keys for mongory-core to merge' do
        expect(result).to eq('user.name' => 'Frank', 'user.age' => 20)
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

      it 'preserves dotted key and normalizes nested operator keys' do
        expect(result).to eq('a.b.c' => { 'in' => [1, 2] })
      end
    end
  end

  describe '#freeze' do
    let(:isolated_kc) { Class.new(Mongory::Converters::KeyConverter).instance }
    let(:isolated_vc) { Class.new(Mongory::Converters::ValueConverter).instance }
    let(:isolated_cc) do
      kc = isolated_kc
      vc = isolated_vc
      Class.new(described_class) do
        define_method(:key_converter) { kc }
        define_method(:value_converter) { vc }
      end.instance
    end

    it 'freezes key_converter, value_converter, and itself, returning self' do
      expect(isolated_cc.freeze).to equal(isolated_cc)
      expect(isolated_cc).to be_frozen
      expect(isolated_kc).to be_frozen
      expect(isolated_vc).to be_frozen
    end
  end
end
