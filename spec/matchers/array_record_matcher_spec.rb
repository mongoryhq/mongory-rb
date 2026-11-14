# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::ArrayRecordMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }
    let(:condition) { [] }

    it_behaves_like 'all the sub-matchers of multi matcher has the same context'
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

      it_behaves_like 'all the sub-matchers of multi matcher has the same context'
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

    context 'when condition has leading zero key' do
      let(:condition) { { '01' => 9 } }

      it { is_expected.not_to be_match([1, 9]) }
      it { is_expected.to be_match([{ '01' => 9 }]) }
    end

    context 'when condition is a comparison operator hash on array elements' do
      let(:condition) { { '$gt' => 5 } }

      it { is_expected.to be_match([3, 6, 9]) }
      it { is_expected.not_to be_match([1, 2, 3]) }
    end

    context 'when condition has non-hash $elemMatch' do
      let(:condition) { { '$elemMatch' => 123 } }

      it 'raises Mongory::TypeError on check_validity!' do
        expect { subject.check_validity! }.to raise_error(Mongory::TypeError, '$elemMatch needs a Hash.')
      end
    end
  end
end
