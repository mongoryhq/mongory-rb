# frozen_string_literal: true

require 'spec_helper'

class MockMultiMatcher < Mongory::Matchers::AbstractMultiMatcher
  def build_sub_matcher(arg)
    SimpleMatcher.new(arg)
  end

  def operator
    :all?
  end
end

class SimpleMatcher < Mongory::Matchers::AbstractMatcher
  def match(record)
    record.include?(condition)
  end
end

class UnwrappedMatcher < MockMultiMatcher
  enable_unwrap!
end

RSpec.describe Mongory::Matchers::AbstractMultiMatcher do
  after(:all) do
    Object.send(:remove_const, :MockMultiMatcher)
    Object.send(:remove_const, :SimpleMatcher)
    Object.send(:remove_const, :UnwrappedMatcher)
  end

  describe '#match' do
    subject { MockMultiMatcher.new(['a', 'b']) }

    it { is_expected.to be_match(%w(a b c)) }
    it { is_expected.not_to be_match(%w(b c)) }
  end

  describe '#matchers' do
    subject(:matcher) { MockMultiMatcher.new(['x', 'y', 'x']) }

    it 'builds unique sub-matchers based on uniq_key' do
      keys = matcher.send(:matchers).map(&:uniq_key)
      expect(keys).to eq(keys.uniq)
    end
  end

  describe '.enable_unwrap!' do
    it 'returns the inner matcher when only one subcondition is given' do
      result = UnwrappedMatcher.build(['a'])
      expect(result).to be_a(SimpleMatcher)
    end
  end
end
