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
end
