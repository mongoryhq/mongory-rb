# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Converters::ValueConverter do
  subject { described_class.instance.convert(input) }

  describe '#convert' do
    context 'when given an Array' do
      let(:input) { [1, 'two'] }

      it { is_expected.to eq([1, 'two']) }
    end

    context 'when given a Hash' do
      let(:input) { { age: { gt: 18 } } }

      it { is_expected.to eq('age' => { 'gt' => 18 }) }
    end

    context 'when given a String' do
      let(:input) { 'hello' }

      it { is_expected.to eq('hello') }
    end

    context 'when given an Integer' do
      let(:input) { 42 }

      it { is_expected.to eq(42) }
    end

    context 'when given a Regexp' do
      let(:input) { /foo/i }

      it { is_expected.to eq(/foo/i) }
    end

    context 'when given a Symbol' do
      let(:input) { :status }

      it { is_expected.to eq('status') }
    end

    context 'when given true' do
      let(:input) { true }

      it { is_expected.to eq(true) }
    end

    context 'when given false' do
      let(:input) { false }

      it { is_expected.to eq(false) }
    end

    context 'when given nil' do
      let(:input) { nil }

      it { is_expected.to eq(nil) }
    end

    context 'when given a Float' do
      let(:input) { 3.14 }

      it { is_expected.to eq(3.14) }
    end

    context 'when given an unsupported type' do
      let(:input) { Struct.new(:v).new(1) }

      it 'falls back to DataConverter' do
        is_expected.to eq(input)
      end
    end

    context 'when using symbol operator chaining syntax' do
      let(:input) { { :age.gt => 30 } }

      it 'converts using QueryOperator chaining' do
        is_expected.to eq('age' => { '$gt' => 30 })
      end
    end

    context 'when structure is deeply nested' do
      let(:input) { { :'a.b.c'.in => [1, 2] } }

      it 'produces a deeply nested hash with normalized operator' do
        is_expected.to eq('a' => { 'b' => { 'c' => { '$in' => [1, 2] } } })
      end
    end
  end
end
