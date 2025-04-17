# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::ElemMatchMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when any element matches the condition' do
      let(:condition) { { 'x' => 1 } }

      it { is_expected.to be_match([{ 'x' => 1 }, { 'x' => 2 }]) }
      it { is_expected.to be_match([{ 'x' => 0 }, { 'x' => 1 }]) }
      it { is_expected.not_to be_match([{ 'x' => 2 }, { 'x' => 3 }]) }
    end

    context 'when condition contains operator' do
      let(:condition) { { 'x' => { '$gt' => 10 } } }

      it { is_expected.to be_match([{ 'x' => 5 }, { 'x' => 20 }]) }
      it { is_expected.not_to be_match([{ 'x' => 5 }, { 'x' => 8 }]) }
    end

    context 'when record is not an array' do
      let(:condition) { { 'x' => 1 } }

      it { is_expected.not_to be_match({ 'x' => 1 }) }
      it { is_expected.not_to be_match('invalid') }
      it { is_expected.not_to be_match(nil) }
    end

    context 'when condition is not a hash (invalid usage)' do
      let(:condition) { 'not a hash' }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end
  end
end
