# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::LtMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when condition is number' do
      let(:condition) { 10 }

      it { is_expected.to be_match(9) }
      it { is_expected.not_to be_match(10) }
      it { is_expected.not_to be_match(11) }
      it { is_expected.not_to be_match(nil) }
    end

    context 'when condition is string' do
      let(:condition) { 'b' }

      it { is_expected.to be_match('a') }
      it { is_expected.not_to be_match('b') }
      it { is_expected.not_to be_match('c') }
      it { is_expected.not_to be_match(nil) }
    end

    context 'when condition is nil (invalid usage)' do
      let(:condition) { nil }

      it { is_expected.not_to be_match(10) }
      it { is_expected.not_to be_match(9) }
      it { is_expected.not_to be_match('b') }
      it { is_expected.not_to be_match('a') }
      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match(anything) }
    end
  end
end
