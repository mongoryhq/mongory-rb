# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::NeMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when value does not match' do
      let(:condition) { 42 }

      it { is_expected.to be_match(43) }
      it { is_expected.to be_match(nil) }
      it { is_expected.to be_match(anything) }
      it { is_expected.not_to be_match(42) }
    end

    context 'when condition is nil' do
      let(:condition) { nil }

      it { is_expected.not_to be_match(nil) }
      it { is_expected.to be_match(anything) }
    end
  end
end
