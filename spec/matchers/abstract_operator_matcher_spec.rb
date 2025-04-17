# frozen_string_literal: true

require 'spec_helper'

class MockOperatorMatcher < Mongory::Matchers::AbstractOperatorMatcher
  def operator
    :==
  end
end

RSpec.describe Mongory::Matchers::AbstractOperatorMatcher do
  after(:all) do
    Object.send :remove_const, :MockOperatorMatcher
  end

  describe '#match' do
    subject { MockOperatorMatcher.new(condition) }

    context 'when comparison is valid' do
      let(:condition) { 100 }

      it { is_expected.to be_match(100) }
      it { is_expected.not_to be_match(200) }
    end

    context 'when comparison raises (invalid type)' do
      let(:condition) { :abc }

      it { is_expected.not_to be_match(anything) }
    end

    context 'when record is KEY_NOT_FOUND' do
      let(:condition) { nil }

      it { is_expected.to be_match(described_class::KEY_NOT_FOUND) }
    end
  end

  describe '#preprocess' do
    subject { MockOperatorMatcher.new(anything).send(:preprocess, value) }

    context do
      let(:value) { described_class::KEY_NOT_FOUND }

      it { is_expected.to be nil }
    end

    context do
      let(:value) { anything }

      it { is_expected.to be value }
    end
  end
end
