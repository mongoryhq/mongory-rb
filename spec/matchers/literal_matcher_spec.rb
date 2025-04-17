# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::LiteralMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when condition is a basic literal value' do
      let(:condition) { 123 }

      it { is_expected.to be_match(123) }
      it { is_expected.not_to be_match(456) }
      it { is_expected.not_to be_match(nil) }
    end

    context 'when condition is a Regexp' do
      let(:condition) { /foo/ }

      it { is_expected.to be_match('foobar') }
      it { is_expected.not_to be_match('bar') }
    end

    context 'when condition is nil' do
      let(:condition) { nil }

      it { is_expected.to be_match(nil) }
      it { is_expected.to be_match(described_class::KEY_NOT_FOUND) }
      it { is_expected.not_to be_match('anything') }
    end

    context 'when condition is a hash (treated as query operator)' do
      let(:condition) { { '$gt' => 5 } }

      it { is_expected.to be_match(10) }
      it { is_expected.not_to be_match(3) }
    end

    context 'when record is an array (triggers ArrayRecordMatcher)' do
      let(:condition) { 123 }

      it { is_expected.to be_match([123, 456]) }
      it { is_expected.not_to be_match([456, 789]) }
    end
  end
end
