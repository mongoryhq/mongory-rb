# frozen_string_literal: true

require 'spec_helper'
require 'json'

# Cross-language conformance tests driven by mongory-spec fixtures.
#
# Point MONGORY_SPEC_DIR at a mongory-spec checkout to enable:
#   MONGORY_SPEC_DIR=../mongory-spec bundle exec rspec spec/conformance_spec.rb
#
# Without MONGORY_SPEC_DIR the whole group is skipped, so the default `rake`
# task keeps working offline.
spec_dir = ENV.fetch('MONGORY_SPEC_DIR', nil)
fixtures_dir = spec_dir && File.join(spec_dir, 'fixtures')
fixture_files = fixtures_dir && Dir.exist?(fixtures_dir) ? Dir.glob(File.join(fixtures_dir, '**', '*.json')).sort : []

RSpec.describe 'mongory-spec conformance' do
  if fixture_files.empty?
    it 'is skipped because MONGORY_SPEC_DIR is not set or has no fixtures' do
      skip 'set MONGORY_SPEC_DIR to a mongory-spec checkout to run conformance tests'
    end
  end

  engines = { 'QueryMatcher' => Mongory::QueryMatcher }
  engines['CMatcher'] = Mongory::CMatcher if defined?(Mongory::CMatcher)

  build_matcher = lambda do |klass, condition|
    klass.new(condition).tap do |matcher|
      matcher.prepare_query if matcher.respond_to?(:prepare_query)
    end
  end

  fixture_files.each do |file|
    relative_path = file.delete_prefix("#{fixtures_dir}/")

    describe relative_path do
      JSON.parse(File.read(file)).each do |suite|
        describe suite['description'] do
          engines.each do |engine_name, klass|
            context "with #{engine_name}" do
              if suite['error']
                it 'rejects the condition' do
                  expect { build_matcher.call(klass, suite['condition']) }.to raise_error(Mongory::TypeError)
                end
              else
                let(:matcher) { build_matcher.call(klass, suite['condition']) }

                suite['records'].each_with_index do |record, index|
                  it "record ##{index} #{record['data'].to_json} => #{record['expected']}" do
                    expect(matcher.match?(record['data'])).to be(record['expected'])
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
