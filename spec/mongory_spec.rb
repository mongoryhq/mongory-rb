# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mongory do
  it 'has a version number' do
    expect(Mongory::VERSION).not_to be nil
  end

  describe '.enable_c_extension_by_default! / .disable_c_extension_by_default!' do
    let(:records) { [{ 'name' => 'Alice', 'age' => 30 }] }

    after do
      described_class.disable_c_extension_by_default!
    end

    it 'uses QueryBuilder by default when not enabled' do
      expect(described_class.c_extension_by_default?).to be false
      expect(described_class.build_query(records)).to be_an_instance_of(Mongory::QueryBuilder)
      expect(records.mongory).to be_an_instance_of(Mongory::QueryBuilder)
    end

    it 'uses CQueryBuilder by default when enabled and CMatcher is available' do
      result = described_class.enable_c_extension_by_default!
      expect(result).to be true
      expect(described_class.c_extension_by_default?).to be true
      expect(described_class.build_query(records)).to be_an_instance_of(Mongory::CQueryBuilder)
      expect(records.mongory).to be_an_instance_of(Mongory::CQueryBuilder)
    end

    it 'reverts to QueryBuilder after disable_c_extension_by_default!' do
      described_class.enable_c_extension_by_default!
      described_class.disable_c_extension_by_default!
      expect(described_class.c_extension_by_default?).to be false
      expect(described_class.build_query(records)).to be_an_instance_of(Mongory::QueryBuilder)
      expect(records.mongory).to be_an_instance_of(Mongory::QueryBuilder)
    end
  end

  describe '.configure and internal constants' do
    it 'freezes internal sentinel and proc constants' do
      expect(Mongory::Converters::AbstractConverter::NOTHING).to be_frozen
      expect(Mongory::Matchers::AbstractMatcher::KEY_NOT_FOUND).to be_frozen
      expect(Mongory::Matchers::AbstractMultiMatcher::TRUE_PROC).to be_frozen
      expect(Mongory::Matchers::AbstractMultiMatcher::FALSE_PROC).to be_frozen
    end

    it 'yields self and calls freeze at the end of .configure' do
      expect(described_class).to receive(:freeze).and_return(described_class)
      yielded = nil
      result = described_class.configure { |mc| yielded = mc }
      expect(yielded).to equal(described_class)
      expect(result).to equal(described_class)
    end

    it 'warns without NameError when validating a duplicate operator' do
      expect do
        Mongory::Matchers::Validator.validate_operator('$eq', Mongory::Matchers::EqMatcher)
      end.to output(/Duplicate operator registration: \$eq/).to_stderr
    end
  end
end
