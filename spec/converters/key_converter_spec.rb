# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Converters::KeyConverter do
  describe '#convert' do
    subject(:result) do
      key, value = input.first
      described_class.instance.convert(key, value)
    end

    context 'when input is a symbol key' do
      let(:input) { { age: anything } }

      it 'converts symbol to string and applies key normalization' do
        expect(result).to eq('age' => anything)
      end
    end

    context 'when input is a QueryOperator' do
      let(:input) do
        op = Mongory::QueryOperator.new('score', '$lte')
        { op => anything }
      end

      it 'delegates to QueryOperator#__expr_part__' do
        expect(result).to eq('score' => { '$lte' => anything })
      end
    end
  end

  describe '#convert_string_key' do
    subject(:result) { described_class.instance.convert_string_key(key, value) }

    let(:value) { 'target' }

    context 'when key has no dot' do
      let(:key) { 'simple' }

      it 'returns a single-level hash' do
        expect(result).to eq('simple' => value)
      end
    end

    context 'when key has one dot' do
      let(:key) { 'user.name' }

      it 'returns a nested hash' do
        expect(result).to eq('user' => { 'name' => value })
      end
    end

    context 'when key has multiple dots' do
      let(:key) { 'a.b.c.d' }

      it 'returns deeply nested hash' do
        expect(result).to eq('a' => { 'b' => { 'c' => { 'd' => value } } })
      end
    end

    context 'when key contains escaped dot' do
      let(:key) { 'user\.name.age' }

      it 'preserves escaped dot as literal' do
        expect(result).to eq('user.name' => { 'age' => value })
      end
    end

    context 'when key contains double backslash' do
      let(:key) { 'foo\\\\bar.baz' }

      it 'treats backslash as literal and splits correctly' do
        expect(result).to eq('foo\\\\bar' => { 'baz' => value })
      end
    end

    context 'when key ends with escaped dot' do
      let(:key) { 'a\.b\.' }

      it 'preserves literal dot at end' do
        expect(result).to eq('a.b.' => value)
      end
    end

    context 'when key is fully escaped' do
      let(:key) { 'a\.b\.c' }

      it 'preserves all escaped dots as part of key' do
        expect(result).to eq('a.b.c' => value)
      end
    end
  end
end
