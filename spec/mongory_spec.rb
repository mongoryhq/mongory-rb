# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory do
  it 'has a version number' do
    expect(Mongory::VERSION).not_to be nil
  end

  describe '.query / .build_query / .compile / .build_matcher' do
    let(:records) { [{ 'name' => 'Alice', 'age' => 30 }] }

    it 'builds QueryBuilder and Matcher backed by mongory-core' do
      expect(described_class.query(records)).to be_an_instance_of(Mongory::QueryBuilder)
      expect(described_class.build_query(records)).to be_an_instance_of(Mongory::QueryBuilder)
      expect(described_class.compile(name: 'Alice')).to be_an_instance_of(Mongory::Matcher)
      expect(described_class.compile(name: 'Alice').match?(name: 'Alice')).to be true
      expect(described_class.build_matcher(name: 'Alice')).to be_an_instance_of(Mongory::Matcher)
      expect(records.mongory).to be_an_instance_of(Mongory::QueryBuilder)
    end
  end

  describe '.configure and internal constants' do
    it 'freezes internal sentinel constants' do
      expect(Mongory::Converters::AbstractConverter::NOTHING).to be_frozen
    end

    it 'yields self and calls freeze at the end of .configure' do
      expect(described_class).to receive(:freeze).and_return(described_class)
      yielded = nil
      result = described_class.configure { |mc| yielded = mc }
      expect(yielded).to equal(described_class)
      expect(result).to equal(described_class)
    end

    it 'warns without NameError when validating a duplicate operator' do
      dummy_matcher = Class.new(Mongory::Matchers::AbstractMatcher)
      expect do
        Mongory::Matchers::Validator.validate_operator('$eq', dummy_matcher)
      end.to output(/Duplicate operator registration: \$eq/).to_stderr
    end
  end

  describe 'C extension load verification' do
    it 'raises LoadError if mongory_ext loads without defining Mongory::Matcher' do
      require 'open3'
      require 'rbconfig'
      require 'tmpdir'

      lib_dir = File.expand_path('../lib', __dir__)
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'mongory_ext.rb'), "# stale extension stub\n")
        script = <<~RUBY
          module Kernel
            def require_relative(path)
              raise LoadError, 'simulated missing core ext' if path.start_with?('core/')

              base = File.dirname(caller_locations(1, 1).first.absolute_path)
              require File.expand_path(path, base)
            end
          end
          require 'mongory'
        RUBY
        _stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib_dir, '-I', dir, '-e', script)
        expect(status.success?).to be false
        expect(stderr).to include('Incompatible or outdated mongory_ext')
      end
    end
  end
end
