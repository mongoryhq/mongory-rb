# frozen_string_literal: true

require 'spec_helper'

class MockMatcher < Mongory::Matchers::AbstractMatcher
  def match(record)
    record == condition
  end
end

RSpec.describe Mongory::Matchers::AbstractMatcher do
  after(:all) do
    Object.send :remove_const, :MockMatcher
  end

  describe '#match?' do
    subject { MockMatcher.new(42) }

    it { is_expected.to be_match(42) }
    it { is_expected.not_to be_match(24) }
  end

  describe '#normalize' do
    subject { MockMatcher.new(nil).send(:normalize, value) }

    context 'converts KEY_NOT_FOUND to nil' do
      let(:value) { described_class::KEY_NOT_FOUND }

      it { is_expected.to be nil }
    end

    context 'preserves other values' do
      let(:value) { anything }

      it { is_expected.to be value }
    end
  end

  describe '#uniq_key' do
    subject { MockMatcher.new(42).uniq_key }

    it { is_expected.to be_match('MockMatcher:condition') }
  end

  describe '#tree_title' do
    subject { MockMatcher.new('abc').send(:tree_title) }

    it { is_expected.to be_match(/Mock: "abc"/) }
  end

  describe '#check_validity!' do
    subject { MockMatcher.new('x').check_validity! }

    it { is_expected.to be nil }
    it { expect { subject }.not_to raise_error }
  end
end
