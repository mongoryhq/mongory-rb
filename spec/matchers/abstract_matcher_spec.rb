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

  describe '#check_validity!' do
    subject { MockMatcher.new('x').check_validity! }

    it { is_expected.to be nil }
    it { expect { subject }.not_to raise_error }
  end
end
