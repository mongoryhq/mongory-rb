# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::PresentMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when condition is true (value must be present)' do
      let(:condition) { true }

      it { is_expected.to be_match('value') }
      it { is_expected.not_to be_match('') }
      it { is_expected.not_to be_match([]) }
      it { is_expected.not_to be_match({}) }
      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match(described_class::KEY_NOT_FOUND) }
    end

    context 'when condition is false (value must be blank)' do
      let(:condition) { false }

      it { is_expected.not_to be_match('value') }
      it { is_expected.to be_match('') }
      it { is_expected.to be_match([]) }
      it { is_expected.to be_match({}) }
      it { is_expected.to be_match(nil) }
      it { is_expected.to be_match(described_class::KEY_NOT_FOUND) }
    end

    context 'when condition is not a boolean (invalid usage)' do
      let(:condition) { 'yes' }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end
  end
end
