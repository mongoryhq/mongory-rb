# frozen_string_literal: true

require 'time'
require 'date'
require 'set'
require 'singleton'
require_relative 'mongory/version'
require_relative 'mongory/utils'
require_relative 'mongory/matchers'
require_relative 'mongory/query_matcher'
require_relative 'mongory/query_builder'
require_relative 'mongory/query_operator'
require_relative 'mongory/converters'
require_relative 'mongory/rails' if defined?(Rails::Railtie)
require_relative 'mongory/mongoid' if defined?(Mongoid)

# Main namespace for Mongory DSL and configuration.
#
# Provides access to core converters, query construction, and optional
# integrations with frameworks like Rails or Mongoid.
#
# @example Basic usage
#   Mongory.build_query(records).where(age: { :$gt => 18 })
#
# @example Enabling DSL snippets
#   Mongory.enable_symbol_snippets!
#   Mongory.register(Array)
module Mongory
  class Error < StandardError; end
  class TypeError < Error; end

  @c_extension_by_default = false

  # Yields Mongory for configuration and freezes key components.
  #
  # @example Configure converters
  #   Mongory.configure do |mc|
  #     mc.data_converter.configure do |dc|
  #       dc.register(MyType) { transform(self) }
  #     end
  #
  #     mc.condition_converter.key_converter.configure do |kc|
  #       kc.register(MyKeyType) { normalize_key(self) }
  #     end
  #
  #     mc.condition_converter.value_converter.configure do |vc|
  #       vc.register(MyValueType) { cast_value(self) }
  #     end
  #   end
  #
  # @yieldparam self [Mongory]
  # @return [self]
  def self.configure
    yield self
    freeze
  end

  # Freezes Mongory configuration, converters, and matchers.
  #
  # @return [self]
  def self.freeze
    data_converter.freeze
    condition_converter.freeze
    @debugger = Utils::Debugger.instance
    Matchers.freeze
    super
  end

  # Returns the data converter instance.
  #
  # @return [Converters::DataConverter]
  def self.data_converter
    @data_converter ||= Converters::DataConverter.instance
  end

  # Returns the condition converter instance.
  #
  # @return [Converters::ConditionConverter]
  def self.condition_converter
    @condition_converter ||= Converters::ConditionConverter.instance
  end

  # Returns the debugger instance.
  #
  # @return [Utils::Debugger]
  def self.debugger
    @debugger ||= Utils::Debugger.instance
  end

  # Builds a new query over the given record set.
  # Uses `CQueryBuilder` when `enable_c_extension_by_default!` is enabled and the C extension is available;
  # otherwise uses `QueryBuilder`.
  #
  # @param records [Enumerable] any enumerable object (Array, AR::Relation, etc.)
  # @return [QueryBuilder, CQueryBuilder] a new query builder
  def self.build_query(records)
    builder_class = c_extension_by_default? ? CQueryBuilder : QueryBuilder
    builder_class.new(records)
  end

  # Registers a class to support `.mongory` query DSL.
  # This injects a `#mongory` method into the given class.
  #
  # @param klass [Class] the class to register (e.g., Array, ActiveRecord::Relation)
  # @return [void]
  def self.register(klass)
    klass.include(ClassExtention)
  end

  # Enables symbol snippets like `:age.gte` or `:name.regex`
  # by dynamically defining methods on `Symbol` for query operators.
  #
  # Skips operators that already exist to avoid patching Mongoid or other gems.
  #
  # @return [void]
  def self.enable_symbol_snippets!
    Matchers.enable_symbol_snippets!
  end

  # Enables using the C extension (`CQueryBuilder`) by default when building queries
  # via `Mongory.build_query` or `.mongory`.
  #
  # Automatically falls back to the pure Ruby `QueryBuilder` if the C extension is unavailable.
  #
  # @return [Boolean] true if C extension is available and enabled by default
  def self.enable_c_extension_by_default!
    @c_extension_by_default = !defined?(Mongory::CMatcher).nil?
  end

  singleton_class.alias_method :use_c_extension_by_default!, :enable_c_extension_by_default!

  # Disables using the C extension by default, reverting `.mongory` and `Mongory.build_query`
  # to the pure Ruby `QueryBuilder`.
  #
  # @return [void]
  def self.disable_c_extension_by_default!
    @c_extension_by_default = false
  end

  # Returns whether the C extension is used by default for queries.
  #
  # @return [Boolean]
  def self.c_extension_by_default?
    @c_extension_by_default == true && !defined?(Mongory::CMatcher).nil?
  end

  # Adds a `#mongory` method to the target class via inclusion.
  #
  # Typically used internally by `Mongory.register(...)`.
  module ClassExtention
    # Returns a query builder scoped to `self`.
    #
    # @return [QueryBuilder, CQueryBuilder]
    def mongory
      Mongory.build_query(self)
    end
  end
end

begin
  abi = RUBY_VERSION.split('.').first(2).join('.')
  require_relative "core/#{abi}/mongory_ext"
  require_relative 'mongory/c_query_builder'
  require_relative 'mongory/c_matcher'
rescue LoadError => e
  warn("Mongory C extension is disabled because mongory_ext is not loaded: #{e.message}")
end
