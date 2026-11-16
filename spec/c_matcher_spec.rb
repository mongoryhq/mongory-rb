# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_matcher_spec'

RSpec.describe Mongory::CMatcher, type: :model do
  describe '#match?' do
    subject { described_class.new(condition) }

    it_behaves_like 'matcher behavior'
  end

  describe 'trace lifecycle edge cases' do
    subject(:matcher) { described_class.new(condition) }

    let(:condition) { { name: 'John' } }
    let(:raw_hash) { { 0 => 'admin' } }
    let(:custom_condition) { { user: DummyModel.new(raw_hash) } }

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
      custom_matcher = described_class.new(custom_condition)
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

  describe 'allocation and initialization lifecycle' do
    it 'supports subclassing with custom #initialize calling super' do
      subclass = Class.new(described_class) do
        attr_reader :tag

        def initialize(cond, tag:)
          super(cond)
          @tag = tag
        end
      end

      instance = subclass.new({ name: 'John' }, tag: :custom)
      expect(instance.tag).to eq(:custom)
      expect(instance.match?(name: 'John')).to be true
      expect(instance.match?(name: 'Mary')).to be false
    end

    it 'raises Mongory::Error when using an allocated but uninitialized instance' do
      uninitialized = described_class.allocate
      expect { uninitialized.match?(name: 'John') }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.condition }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.context }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.explain }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.trace(name: 'John') }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.enable_trace }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.disable_trace }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.print_trace }.to raise_error(Mongory::Error, /uninitialized/)
      GC.start
    end

    it 'cleans up safely when #initialize raises and GC runs' do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(name: { '$unknown' => 1 }) }.to raise_error(Mongory::TypeError)
      GC.start
    end

    it 'forbids dup and clone to prevent sharing C memory pools' do
      matcher = described_class.new(name: 'John')
      expect { matcher.dup }.to raise_error(TypeError, /can't copy/)
      expect { matcher.clone }.to raise_error(TypeError, /can't copy/)
    end
  end

  describe 'thread safety' do
    it 'safely shares a CMatcher across threads with lazy array and regex matching' do
      matcher = described_class.new(
        tags: 'ruby',
        scores: { '$gt' => 5, '$lt' => 8 },
        note: { '$regex' => '^ok', '$options' => 'i' }
      )

      results = Array.new(8) do |t|
        Thread.new do
          200.times.all? do |i|
            matcher.match?(tags: %w(go ruby), scores: [3, 6, 9], note: "OK_#{t}_#{i}") &&
              !matcher.match?(tags: %w(py), scores: [1, 9], note: 'no')
          end
        end
      end.map(&:value)

      GC.start
      expect(results).to all(be true)
      expect(matcher.match?(tags: 'ruby', scores: 6, note: 'ok')).to be true
    end
  end
end
