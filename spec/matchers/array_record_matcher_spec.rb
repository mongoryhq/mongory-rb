# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::ArrayRecordMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when record is equal to condition' do
      let(:condition) { [1, 2, 3] }

      it { is_expected.to be_match([1, 2, 3]) }
      it { is_expected.not_to be_match([3, 2, 1]) }
    end

    context 'when condition is a scalar and record is an array' do
      let(:condition) { 42 }

      it { is_expected.to be_match([10, 42, 99]) }
      it { is_expected.not_to be_match([1, 2, 3]) }
    end

    context 'when condition is an operator hash' do
      let(:condition) { { '0' => { '$gt' => 10 } } }

      it { is_expected.to be_match([20, 30]) }
      it { is_expected.not_to be_match([5, 8, 10]) }
    end

    context 'when condition is a hash with element field match' do
      let(:condition) { { 'x' => 1 } }

      it { is_expected.to be_match([{ 'x' => 1 }, { 'x' => 2 }]) }
      it { is_expected.not_to be_match([{ 'x' => 2 }, { 'x' => 3 }]) }
    end

    context 'when condition has index key as string' do
      let(:condition) { { '0' => 42 } }

      it { is_expected.to be_match([42, 38]) }
      it { is_expected.to be_match([[12, 42], [99]]) }
      it { is_expected.not_to be_match([[1, 2], [3, 4]]) }
    end

    context 'when condition has index key as integer' do
      let(:condition) { { 0 => 9 } }

      it { is_expected.to be_match([9, 1]) }
      it { is_expected.to be_match([[0, 9], [1, 2]]) }
      it { is_expected.not_to be_match([[0, 3], [1, 2]]) }
    end
  end
end
