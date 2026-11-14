# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory::Matchers::FieldMatcher do
  describe '#match?' do
    subject { described_class.new(field, condition) }

    context 'when field exists and matches' do
      let(:field) { 'x' }
      let(:condition) { 1 }

      it { is_expected.to be_match('x' => 1) }
      it { is_expected.not_to be_match('x' => 2) }
      it { is_expected.not_to be_match({}) }
      it { is_expected.not_to be_match(nil) }
      it { is_expected.not_to be_match(described_class::KEY_NOT_FOUND) }
      it { is_expected.not_to be_match('string') }
      it { is_expected.not_to be_match(:symbol) }
      it { is_expected.not_to be_match(123) }
    end

    context 'when value is nil and condition is nil' do
      let(:field) { 'x' }
      let(:condition) { nil }

      it { is_expected.to be_match('x' => nil) }
      it { is_expected.to be_match({}) }
      it { is_expected.not_to be_match('x' => anything) }
    end

    context 'when extracted value is an array' do
      let(:field) { 'x' }
      let(:condition) { 1 }

      it { is_expected.to be_match('x' => [1, 2]) }
      it { is_expected.not_to be_match('x' => [3, 4]) }
    end

    context 'when field is a string integer index and record is an array or hash' do
      let(:field) { '0' }
      let(:condition) { 'ruby' }

      it { is_expected.to be_match(%w(ruby c)) }
      it { is_expected.not_to be_match(%w(c ruby)) }
      it { is_expected.to be_match('0' => 'ruby') }
      it { is_expected.to be_match('0': 'ruby') }
    end

    context 'when field is an integer and record is an array or hash' do
      let(:field) { 0 }
      let(:condition) { 'ruby' }

      it { is_expected.to be_match(%w(ruby c)) }
      it { is_expected.not_to be_match(%w(c ruby)) }
      it { is_expected.to be_match('0' => 'ruby') }
      it { is_expected.to be_match('0': 'ruby') }
    end

    context 'when field has leading zero and record is an array or hash' do
      let(:field) { '01' }
      let(:condition) { 'c' }

      it { is_expected.not_to be_match(%w(ruby c)) }
      it { is_expected.to be_match('01' => 'c') }
      it { is_expected.to be_match('01': 'c') }
    end
  end
end
