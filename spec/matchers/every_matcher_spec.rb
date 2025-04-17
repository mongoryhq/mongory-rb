# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::EveryMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when all elements match the condition' do
      let(:condition) { { 'status' => 'active' } }

      it { is_expected.to be_match([{ 'status' => 'active' }, { 'status' => 'active' }]) }
      it { is_expected.not_to be_match([{ 'status' => 'active' }, { 'status' => 'inactive' }]) }
      it { is_expected.not_to be_match([{ 'status' => 'active' }, {}]) }
      it { is_expected.not_to be_match([]) }
      it { is_expected.not_to be_match('not an array') }
      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match(anything) }
    end

    context 'when condition is not a hash (invalid)' do
      let(:condition) { 'invalid' }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end
  end
end
