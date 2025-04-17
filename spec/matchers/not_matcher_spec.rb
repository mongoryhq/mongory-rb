# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::NotMatcher do
  describe '#match?' do
    subject { described_class.new(condition) }

    context 'when condition is a comparison matcher' do
      let(:condition) { { '$gte' => 10 } }

      it { is_expected.to be_match(5) }
      it { is_expected.not_to be_match(15) }
    end

    context 'when condition is a regexp' do
      let(:condition) { /foo/ }

      it { is_expected.to be_match('bar') }
      it { is_expected.not_to be_match('foobar') }
    end

    context 'when condition is a literal value' do
      let(:condition) { 123 }

      it { is_expected.to be_match(456) }
      it { is_expected.not_to be_match(123) }
    end

    context 'when condition is invalid (not a matcher or literal)' do
      let(:condition) { { '$regex' => anything } }

      it 'raises Mongory::TypeError' do
        expect { subject }.to raise_error(Mongory::TypeError)
      end
    end
  end
end
