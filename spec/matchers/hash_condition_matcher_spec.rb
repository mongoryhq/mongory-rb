# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::HashConditionMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }
    let(:condition) { {} }

    it_behaves_like 'all the sub-matchers of multi matcher has the same context'
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

      it_behaves_like 'all the sub-matchers of multi matcher has the same context'
      it { is_expected.to be_match('x' => 20) }
      it { is_expected.not_to be_match('x' => 5) }
      it { is_expected.not_to be_match({}) }
    end

    context 'when all subconditions must match' do
      let(:condition) { { 'x' => { '$gt' => 10 }, 'y' => 1 } }

      it_behaves_like 'all the sub-matchers of multi matcher has the same context'
      it { is_expected.to be_match('x' => 20, 'y' => 1) }
      it { is_expected.not_to be_match('x' => 5, 'y' => 1) }
      it { is_expected.not_to be_match('x' => 20, 'y' => 2) }
    end

    context 'when condition has $regex with $options' do
      let(:condition) { { '$regex' => '^ab', '$options' => 'is' } }

      it { is_expected.to be_match('ABC') }
      it { is_expected.not_to be_match('xab') }
    end
  end

  describe 'condition validation' do
    subject(:build) { described_class.new(condition) }

    context 'when an operator is unknown' do
      let(:condition) { { 'x' => { '$foo' => 1 } } }

      it { expect { build }.to raise_error(Mongory::TypeError, /unknown operator \$foo/) }
    end

    context 'when an unknown operator is nested in $elemMatch' do
      let(:condition) { { 'xs' => { '$elemMatch' => { '$foo' => 1 } } } }

      it { expect { build }.to raise_error(Mongory::TypeError, /unknown operator/) }
    end

    context 'when $options has no sibling $regex' do
      let(:condition) { { 'x' => { '$options' => 'i' } } }

      it { expect { build }.to raise_error(Mongory::TypeError, /\$options needs a sibling \$regex/) }
    end

    context 'when a key only contains $ after the first character' do
      let(:condition) { { 'price$' => 1 } }

      it { is_expected.to be_match('price$' => 1) }
    end
  end
end
