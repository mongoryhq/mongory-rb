# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mongory.data_converter' do
  subject { Mongory.data_converter }

  describe 'interface safety' do
    it 'cannot be instantiated with .new' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end

    it 'cannot be included as a module' do
      expect { Class.new.include(described_class) }.to raise_error(TypeError)
    end
  end

  describe '#convert' do
    context 'when converting primitive types' do
      it 'returns string for symbol' do
        expect(subject.convert(:status)).to eq 'status'
      end

      it 'returns string for date' do
        date = Date.new(2024, 4, 5)
        expect(subject.convert(date)).to eq '2024-04-05'
      end

      it 'returns ISO8601 for time' do
        time = Time.new(2024, 4, 5, 12, 30, 0)
        expect(subject.convert(time)).to eq time.iso8601
      end
    end

    context 'when no conversion is registered' do
      it 'returns the original object' do
        obj = Object.new
        expect(subject.convert(obj)).to equal(obj)
      end
    end
  end

  describe '#register and override behavior' do
    let(:klass) { Struct.new(:val) }

    before do
      subject.register(klass) { "original:#{val}" }
    end

    it 'uses the most recently registered converter' do
      instance = klass.new('foo')
      expect(subject.convert(instance)).to eq('original:foo')

      subject.register(klass) { "new:#{val.upcase}" }
      expect(subject.convert(instance)).to eq('new:FOO')
    end
  end
end
