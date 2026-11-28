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

    context 'when input is an integer key' do
      let(:input) { { 0 => anything } }

      it 'converts integer to string and applies key normalization' do
        expect(result).to eq('0' => anything)
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

    context 'when key has dots or escaped dots' do
      let(:key) { 'user\.name.age' }

      it 'preserves the string key verbatim for mongory-core to expand' do
        expect(result).to eq('user\.name.age' => value)
      end
    end
  end
end
