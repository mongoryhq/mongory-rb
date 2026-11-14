# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::RegexMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when condition is a Regexp' do
      let(:condition) { /foo/ }

      it { is_expected.to be_match('foobar') }
      it { is_expected.not_to be_match('bar') }
      it { is_expected.not_to be_match(:foobar) }
      it { is_expected.not_to be_match(123) }
      it { is_expected.not_to be_match(nil) }
    end

    context 'when condition is a String (auto-converted to Regexp)' do
      let(:condition) { '^bar$' }

      it { is_expected.to be_match('bar') }
      it { is_expected.not_to be_match(' foobar ') }
    end

    context 'when condition is not Regexp or String (invalid usage)' do
      let(:condition) { 123 }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end
  end

  describe '.apply_options' do
    it 'maps i to IGNORECASE' do
      expect(described_class.apply_options('^ab', 'i')).to match('ABC')
    end

    it 'maps s to Ruby MULTILINE so dot matches newline' do
      expect(described_class.apply_options('a.b', 's')).to match("a\nb")
      expect(described_class.apply_options('a.b', '')).not_to match("a\nb")
    end

    it 'accepts m because Ruby anchors already match at line boundaries' do
      expect(described_class.apply_options('^b$', 'm')).to match("a\nb\nc")
    end

    it 'rejects unsupported flags' do
      expect { described_class.apply_options('a', 'x') }
        .to raise_error(Mongory::TypeError, /unsupported \$options flag "x"/)
    end

    it 'rejects a non-string options value' do
      expect { described_class.apply_options('a', 1) }.to raise_error(Mongory::TypeError, /needs a string/)
    end

    it 'rejects options on a Regexp pattern' do
      expect { described_class.apply_options(/a/, 'i') }.to raise_error(Mongory::TypeError, /cannot modify a Regexp/)
    end

    it 'leaves a non-string pattern for check_validity! to reject' do
      expect(described_class.apply_options(123, 'i')).to eq(123)
    end
  end
end
