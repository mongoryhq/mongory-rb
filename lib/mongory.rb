# frozen_string_literal: true

require 'time'
require 'date'
require 'set'
require 'singleton'
require_relative 'mongory/version'
require_relative 'mongory/utils'
require_relative 'mongory/matchers'
require_relative 'mongory/query_operator'
require_relative 'mongory/converters'
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

  # Builds a new query over the given record set.
  #
  # @param records [Enumerable] any enumerable object (Array, AR::Relation, etc.)
  # @return [QueryBuilder] a new query builder
  def self.build_query(records)
    QueryBuilder.new(records)
  end

  # Builds a new matcher for the given condition.
  #
  # @param condition [Hash] the query condition
  # @return [Matcher] a new matcher
  def self.build_matcher(condition)
    Matcher.new(condition)
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

  # Adds a `#mongory` method to the target class via inclusion.
  #
  # Typically used internally by `Mongory.register(...)`.
  module ClassExtention
    # Returns a query builder scoped to `self`.
    #
    # @return [QueryBuilder]
    def mongory
      Mongory.build_query(self)
    end
  end
end

abi = RUBY_VERSION.split('.').first(2).join('.')
require_relative "core/#{abi}/mongory_ext"
require_relative 'mongory/matcher'
require_relative 'mongory/query_builder'
