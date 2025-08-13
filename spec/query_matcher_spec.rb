# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_matcher_spec'

RSpec.describe Mongory::QueryMatcher, type: :model do
  describe '#match?' do
    subject { described_class.new(condition).tap(&:prepare_query) }

    it_behaves_like 'matcher behavior'
  end

  describe '#to_proc' do
    subject do
      double('FakeMatcher').tap do |fake|
        matcher.prepare_query
        allow(fake).to receive(:match?) do |doc|
          matcher.to_proc.call(doc)
        end
      end
    end

    let(:matcher) { described_class.new(condition) }

    it_behaves_like 'matcher behavior'
  end
end
