# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_matcher_spec'

RSpec.describe Mongory::CMatcher, type: :model do
  describe '#match?' do
    subject { described_class.new(condition) }

    it_behaves_like 'matcher behavior'
  end
end
