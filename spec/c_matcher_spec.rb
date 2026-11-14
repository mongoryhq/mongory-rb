# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_matcher_spec'

RSpec.describe Mongory::CMatcher, type: :model do
  describe '#match?' do
    subject { described_class.new(condition) }

    it_behaves_like 'matcher behavior'
  end

  describe 'trace lifecycle edge cases' do
    subject(:matcher) { described_class.new(name: 'John') }

    it 'allows calling disable_trace without prior enable_trace' do
      expect { matcher.disable_trace }.not_to raise_error
    end

    it 'allows calling print_trace without prior enable_trace' do
      expect { matcher.print_trace }.not_to raise_error
    end

    it 'traces matching without corrupting pool owner' do
      expect(matcher.trace(name: 'John')).to be true
      expect(matcher.trace(name: 'Mary')).to be false
    end

    it 'handles DataConverter-converted hashes with integer keys' do
      custom_matcher = described_class.new(user: DummyModel.new(0 => 'admin'))
      expect(custom_matcher.match?(user: %w(admin guest))).to be true
      expect(custom_matcher.match?(user: { '0' => 'admin' })).to be true
      expect(custom_matcher.match?(user: %w(guest admin))).to be false
    end

    it 'supports enable_trace, match?, print_trace, and disable_trace lifecycle' do
      matcher.enable_trace
      expect(matcher.match?(name: 'John')).to be true
      expect { matcher.print_trace }.not_to raise_error
      expect { matcher.disable_trace }.not_to raise_error
    end
  end
end
