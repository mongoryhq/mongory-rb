# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::HashConditionMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when condition is a single field matcher' do
      let(:condition) { { 'x' => 1 } }

      it { is_expected.to be_match('x' => 1) }
      it { is_expected.not_to be_match('x' => 2) }
      it { is_expected.not_to be_match({}) }
    end

    context 'when condition is a single operator matcher' do
      let(:condition) { { '$gt' => 5 } }

      it { is_expected.to be_match(10) }
      it { is_expected.not_to be_match(3) }
    end

    context 'when condition is mixed: field + operator' do
      let(:condition) { { 'x' => { '$gt' => 10 }, '$exists' => true } }

      it { is_expected.to be_match('x' => 20) }
      it { is_expected.not_to be_match('x' => 5) }
      it { is_expected.not_to be_match({}) }
    end

    context 'when all subconditions must match' do
      let(:condition) { { 'x' => { '$gt' => 10 }, 'y' => 1 } }

      it { is_expected.to be_match('x' => 20, 'y' => 1) }
      it { is_expected.not_to be_match('x' => 5, 'y' => 1) }
      it { is_expected.not_to be_match('x' => 20, 'y' => 2) }
    end
  end
end
