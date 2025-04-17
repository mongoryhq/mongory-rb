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
end
