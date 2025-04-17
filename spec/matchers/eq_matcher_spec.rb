# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::EqMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when value matches exactly' do
      let(:condition) { 42 }

      it { is_expected.to be_match(42) }
      it { is_expected.not_to be_match(43) }
      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match(anything) }
    end

    context 'when value is nil and condition is nil' do
      let(:condition) { nil }

      it { is_expected.to be_match(nil) }
      it { is_expected.not_to be_match(anything) }
    end
  end
end
