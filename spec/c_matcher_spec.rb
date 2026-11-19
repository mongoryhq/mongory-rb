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

    it 'returns structured Hashes from explain_tree and trace_tree and prints them in explain and trace' do
      explain = matcher.explain_tree
      expect(explain).to be_a(Hash)
      expect(explain[:name]).to eq('Field')
      expect(explain[:field]).to eq('name')
      expect(explain[:condition]).to eq('John')
      expect(explain[:children]).to be_an(Array)
      expect { matcher.explain }.to output(/Field: "name"/).to_stdout

      trace = matcher.trace_tree(name: 'John')
      expect(trace).to be_a(Hash)
      expect(trace[:result]).to eq(:pass)
      expect(trace[:record]).to eq(name: 'John')
      expect { expect(matcher.trace(name: 'John')).to be true }.to output(/Matched/).to_stdout
    end

    it 'recursively marks short-circuited branches as :skip in both Ruby and C trace_tree' do
      records = [{ 'status' => 'inactive', 'age' => 20 }, { 'status' => 'active', 'age' => 25 }]
      rb_builder = records.mongory.where('status' => 'active', 'age' => { '$gte' => 18 })
      c_builder = rb_builder.c

      [rb_builder, c_builder].each do |builder|
        explain = builder.explain_tree
        expect(explain).to be_a(Hash)
        expect(explain[:children]).to be_an(Array)
        expect { builder.explain }.to output(/status/).to_stdout

        trees = builder.trace_tree
        expect(trees).to be_an(Array)
        expect(trees.length).to eq(2)
        expect(trees[0][:result]).to eq(:fail)
        expect(trees[1][:result]).to eq(:pass)

        skipped_nodes = []
        collect_skips = lambda do |node|
          skipped_nodes << node if node[:result] == :skip
          (node[:children] || []).each { |child| collect_skips.call(child) }
        end
        collect_skips.call(trees[0])
        expect(skipped_nodes.length).to be >= 2
        expect(skipped_nodes.all? { |n| n[:result] == :skip }).to be true

        expect { builder.trace { |_r| nil } }.to output(/Skipped/).to_stdout
      end
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
      expect { uninitialized.explain_tree }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.explain }.to raise_error(Mongory::Error, /uninitialized/)
      expect { uninitialized.trace_tree(name: 'John') }.to raise_error(Mongory::Error, /uninitialized/)
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

    it 'accepts bare hash conditions and context keyword across Ruby versions' do
      ctx = Mongory::Utils::Context.new
      with_ctx = described_class.new({ name: 'John' }, context: ctx)
      bare_ctx_field = described_class.new(context: 'admin')

      expect(with_ctx.context).to equal(ctx)
      expect(with_ctx.match?(name: 'John')).to be true
      expect(bare_ctx_field.match?(context: 'admin')).to be true
      expect { described_class.new({ name: 'John' }, unknown: 1) }.to raise_error(ArgumentError, /unknown keyword/)
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

    it 'protects scratch_pool on recursive re-entry from DataConverter' do
      matcher = described_class.new(score: { '$gt' => 5 }, tag: 'ok')
      nested_results = []
      nested_record = DummyModel.new(nil)
      nested_record.define_singleton_method(:as_json) do
        nested_results << matcher.match?(score: 1, tag: 'no')
        nested_results << matcher.match?(score: 9, tag: 'ok')
        10
      end

      3.times do
        nested_results.clear
        expect(matcher.match?(score: nested_record, tag: 'ok')).to be true
        expect(nested_results).to eq([false, true])
      end
      expect(matcher.match?(score: 7, tag: 'ok')).to be true
    end

    it 'protects scratch_pool when Ruby threads interleave mid-match' do
      matcher = described_class.new(score: { '$gt' => 5 }, tag: 'ok')
      entered = Queue.new
      resume = Queue.new

      slow_record = DummyModel.new(nil)
      slow_record.define_singleton_method(:as_json) do
        entered << true
        resume.pop
        10
      end

      t1 = Thread.new { matcher.match?(score: slow_record, tag: 'ok') }
      entered.pop
      expect(matcher.match?(score: 2, tag: 'no')).to be false
      expect(matcher.match?(score: 8, tag: 'ok')).to be true
      resume << true

      expect(t1.value).to be true
      expect(matcher.match?(score: 6, tag: 'ok')).to be true
    end

    it 'resets and releases scratch_pool when a callback raises an exception' do
      matcher = described_class.new(score: { '$gt' => 5 }, tag: 'ok')
      boom_record = DummyModel.new(nil)
      boom_record.define_singleton_method(:as_json) { raise 'boom' }

      expect { matcher.match?(score: boom_record, tag: 'ok') }.to raise_error(RuntimeError, 'boom')
      expect(matcher.match?(score: 8, tag: 'ok')).to be true
      expect(matcher.match?(score: 2, tag: 'ok')).to be false
    end
  end
end
