# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::SizeMatcher do
  subject { described_class.new(condition) }

  describe '#match?' do
    context 'when matching exact size' do
      let(:condition) { 3 }

      it { is_expected.to be_match([1, 2, 3]) }
      it { is_expected.not_to be_match([1, 2]) }
    end

    context 'when using $gt' do
      let(:condition) { { '$gt' => 2 } }

      it { is_expected.to be_match([1, 2, 3]) }
      it { is_expected.not_to be_match([1]) }
    end

    context 'when using $lte' do
      let(:condition) { { '$lte' => 3 } }

      it { is_expected.to be_match([1, 2, 3]) }
      it { is_expected.to be_match([]) }
      it { is_expected.not_to be_match([1, 2, 3, 4]) }
    end

    context 'when using $in' do
      let(:condition) { { '$in' => [1, 3, 5] } }

      it { is_expected.to be_match([:a]) }
      it { is_expected.to be_match([:a, :b, :c]) }
      it { is_expected.not_to be_match([1, 2]) }
    end

    context 'when input is not an array' do
      let(:condition) { 1 }

      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match(123) }
      it { is_expected.not_to be_match('string') }
    end
  end
end
