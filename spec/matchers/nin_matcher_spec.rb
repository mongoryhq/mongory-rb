# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::NinMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when condition is array of values' do
      let(:condition) { [1, 2, 3] }

      it { is_expected.to be_match(4) }
      it { is_expected.not_to be_match(2) }
    end

    context 'when condition includes nil' do
      let(:condition) { [nil, ''] }

      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match('') }
      it { is_expected.to be_match('something else') }
    end

    context 'when comparing array to array' do
      let(:condition) { [1, 2, 3] }

      it { is_expected.to be_match([4, 5]) }
      it { is_expected.not_to be_match([2, 5]) }
    end

    context 'when condition is not Enumerable (invalid usage)' do
      let(:condition) { 123 }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end
  end
end
