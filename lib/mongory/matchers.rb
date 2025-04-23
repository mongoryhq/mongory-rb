# frozen_string_literal: true

module Mongory
  # Provides matcher registration and operator-to-class lookup for query evaluation.
  #
  # This module is responsible for:
  # - Mapping Mongo-style operators like "$gt" to matcher classes
  # - Dynamically extending Symbol with query operator snippets (e.g., :age.gt)
  # - Safely isolating symbol extension behind an explicit opt-in flag
  #
  # Matchers are registered using `Matchers.registry(method_sym, operator, klass)`
  # and can be looked up via `Matchers.lookup(operator)`.
  #
  # Symbol snippets are only enabled if `Matchers.enable_symbol_snippets!` is called,
  # preventing namespace pollution unless explicitly requested.
  module Matchers
    @operator_mapping = {}
    @registries = []

    # Registers a matcher class for a given operator and method symbol.
    #
    # @param method_sym [Symbol] the method name to be added to Symbol (e.g., :gt)
    # @param operator [String] the Mongo-style operator (e.g., "$gt")
    # @param klass [Class] the matcher class to associate with the operator
    # @return [void]
    # @raise [ArgumentError] if validations fail
    def self.register(method_sym, operator, klass)
      Validator.validate_method(method_sym)
      Validator.validate_operator(operator)
      Validator.validate_class(klass)

      @operator_mapping[operator] = klass
      registry = Registry.new(method_sym, operator)
      @registries << registry
      return unless @enable_symbol_snippets

      registry.apply!
    end

    # Enables dynamic symbol snippet generation for registered operators.
    # This defines methods like `:age.gt => QueryOperator.new(...)`.
    #
    # @return [void]
    def self.enable_symbol_snippets!
      @enable_symbol_snippets = true
      @registries.each(&:apply!)
    end

    # Retrieves the matcher class associated with a Mongo-style operator.
    #
    # @param operator [String]
    # @return [Class, nil] the registered matcher class or nil if not found
    def self.lookup(operator)
      @operator_mapping[operator]
    end

    # Returns all registered operator keys.
    #
    # @return [Array<String>]
    def self.operators
      @operator_mapping.keys
    end

    def self.freeze
      super
      @operator_mapping.freeze
      @registries.freeze
    end

    # @private
    #
    # Internal helper module used by `Matchers.registry` to validate matcher registration parameters.
    #
    # This includes:
    # - Ensuring operators are valid Mongo-style strings (e.g., "$gt")
    # - Verifying matcher class inheritance
    # - Enforcing naming rules for symbol snippets (e.g., :gt, :not_match)
    #
    # These validations protect against incorrect matcher setup and prevent unsafe symbol definitions.
    #
    # @see Matchers.registry
    module Validator
      # Validates the given operator string.
      # Ensures it matches the Mongo-style format like "$gt".
      # Warns on duplicate registration.
      #
      # @param operator [String]
      # @return [void]
      # @raise [Mongory::TypeError] if operator format is invalid
      def self.validate_operator(operator)
        if Matchers.lookup(operator)
          warn "Duplicate operator registration: #{operator} (#{Matchers.lookup(operator)} vs #{klass})"
        end

        return if operator.is_a?(String) && operator.match?(/^\$[a-z]+([A-Z][a-z]+)*$/)

        raise Mongory::TypeError, "Operator must match /^\$[a-z]+([A-Z][a-z]*)*$/, but got #{operator.inspect}"
      end

      # Validates the matcher class to ensure it is a subclass of AbstractMatcher.
      #
      # @param klass [Class]
      # @return [void]
      # @raise [Mongory::TypeError] if class is not valid
      def self.validate_class(klass)
        return if klass.is_a?(Class) && klass < AbstractMatcher

        raise Mongory::TypeError, "Matcher class must be a subclass of AbstractMatcher, but got #{klass}"
      end

      # Validates the method symbol to ensure it is a valid lowercase underscore symbol (e.g., :gt, :not_match).
      #
      # @param method_sym [Symbol]
      # @return [void]
      # @raise [Mongory::TypeError] if symbol format is invalid
      def self.validate_method(method_sym)
        return if method_sym.is_a?(Symbol) && method_sym.match?(/^([a-z]+_)*[a-z]+$/)

        raise Mongory::TypeError, "Method symbol must match /^([a-z]+_)*[a-z]+$/, but got #{method_sym.inspect}"
      end
    end

    # @private
    #
    # Internal helper representing a registration of an operator and its associated symbol snippet method.
    # Used to delay method definition on Symbol until explicitly enabled.
    #
    # Each instance holds:
    # - the method symbol (e.g., `:gt`)
    # - the corresponding Mongo-style operator (e.g., `"$gt"`)
    #
    # These instances are collected and replayed upon calling `Matchers.enable_symbol_snippets!`.
    #
    # @!attribute method_sym
    #   @return [Symbol] the symbol method name (e.g., :in, :gt, :exists)
    # @!attribute operator
    #   @return [String] the Mongo-style operator this snippet maps to (e.g., "$in")
    Registry = Struct.new(:method_sym, :operator) do
      # Defines a method on Symbol to support operator snippet expansion.
      #
      # @return [void]
      def apply!
        return if Symbol.method_defined?(method_sym)

        operator = operator()
        Symbol.define_method(method_sym) do
          Mongory::QueryOperator.new(to_s, operator)
        end
      end
    end
  end
end

require_relative 'matchers/abstract_matcher'
require_relative 'matchers/abstract_multi_matcher'
require_relative 'matchers/literal_matcher'
require_relative 'matchers/hash_condition_matcher'
require_relative 'matchers/and_matcher'
require_relative 'matchers/array_record_matcher'
require_relative 'matchers/elem_match_matcher'
require_relative 'matchers/every_matcher'
require_relative 'matchers/eq_matcher'
require_relative 'matchers/exists_matcher'
require_relative 'matchers/gt_matcher'
require_relative 'matchers/gte_matcher'
require_relative 'matchers/in_matcher'
require_relative 'matchers/field_matcher'
require_relative 'matchers/lt_matcher'
require_relative 'matchers/lte_matcher'
require_relative 'matchers/ne_matcher'
require_relative 'matchers/nin_matcher'
require_relative 'matchers/not_matcher'
require_relative 'matchers/or_matcher'
require_relative 'matchers/present_matcher'
require_relative 'matchers/regex_matcher'
