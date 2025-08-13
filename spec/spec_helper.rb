# frozen_string_literal: true

require 'mongory'
require_relative 'matchers/shared_spec'

DummyModel = Struct.new(:as_json)
FakeBsonId = Struct.new(:to_s)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  Mongory.enable_symbol_snippets!
  Mongory.register(Array)

  converter = Mongory.data_converter

  converter.register(DummyModel) do
    converter.convert(as_json)
  end

  converter.register(FakeBsonId, :to_s)
end
