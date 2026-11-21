# frozen_string_literal: true

module Mongory
  # Provides custom matcher registration and Symbol operator snippet management.
  #
  # Built-in operators are evaluated natively by `mongory-core` and registered in
  # `BUILTIN_OPERATORS` so `enable_symbol_snippets!` can expose Symbol methods
  # (e.g., `:age.gt`, `:tags.in`).
  #
  # Custom Ruby matchers subclassing `Mongory::Matchers::AbstractMatcher` are registered
  # via `Matchers.register(method_sym, operator, klass)` and bridged into `mongory-core`
  # through `Matchers.lookup(operator)`.
  module Matchers
    # Built-in operators implemented natively in `mongory-core`.
    BUILTIN_OPERATORS = {
      eq: '$eq',
      ne: '$ne',
      gt: '$gt',
      gte: '$gte',
      lt: '$lt',
      lte: '$lte',
      in: '$in',
      nin: '$nin',
      exists: '$exists',
      present: '$present',
      regex: '$regex',
      and: '$and',
      or: '$or',
      not: '$not',
      elem_match: '$elemMatch',
      every: '$every',
      size: '$size'
    }.freeze

    # @private
    #
    # Internal helper representing a registration of an operator and its associated symbol snippet method.
    # Used to delay method definition on Symbol until explicitly enabled.
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

    @operator_mapping = {}
    @registries = BUILTIN_OPERATORS.map { |method_sym, operator| Registry.new(method_sym, operator).freeze }
    @enable_symbol_snippets = false

    # Registers a custom matcher class for a given operator and method symbol.
    #
    # @param method_sym [Symbol] the method name to be added to Symbol (e.g., :class_in)
    # @param operator [String] the Mongo-style operator (e.g., "$classIn")
    # @param klass [Class] the matcher class to associate with the operator
    # @return [void]
    # @raise [Mongory::TypeError] if validations fail
    def self.register(method_sym, operator, klass)
      Validator.validate_method(method_sym)
      Validator.validate_operator(operator, klass)
      Validator.validate_class(klass)

      @operator_mapping[operator] = klass
      registry = Registry.new(method_sym, operator).freeze
      @registries << registry
      return unless @enable_symbol_snippets

      registry.apply!
    end

    # Enables dynamic symbol snippet generation for built-in and registered operators.
    # This defines methods like `:age.gt => QueryOperator.new(...)`.
    #
    # @return [void]
    def self.enable_symbol_snippets!
      @enable_symbol_snippets = true
      @registries.each(&:apply!)
    end

    # Retrieves the custom matcher class associated with a Mongo-style operator.
    # Built-in operators are handled natively by `mongory-core` and return `nil`.
    #
    # @param operator [String]
    # @return [Class, nil] the registered custom matcher class or nil if not found
    def self.lookup(operator)
      @operator_mapping[operator]
    end

    # Returns whether the operator is a built-in `mongory-core` operator.
    #
    # @param operator [String]
    # @return [Boolean]
    def self.builtin?(operator)
      BUILTIN_OPERATORS.value?(operator)
    end

    # Returns all built-in and custom registered operator keys.
    #
    # @return [Array<String>]
    def self.operators
      (BUILTIN_OPERATORS.values + @operator_mapping.keys).uniq
    end

    def self.freeze
      @registries.each(&:freeze)
      @operator_mapping.freeze
      @registries.freeze
      super
    end

    # @private
    #
    # Internal helper module used by `Matchers.register` to validate matcher registration parameters.
    module Validator
      # Validates the given operator string.
      # Ensures it matches the Mongo-style format like "$gt".
      # Warns on duplicate registration.
      #
      # @param operator [String]
      # @param klass [Class, nil]
      # @return [void]
      # @raise [Mongory::TypeError] if operator format is invalid
      def self.validate_operator(operator, klass = nil)
        existing = Matchers.lookup(operator) || (Matchers.builtin?(operator) ? 'built-in' : nil)
        warn "Duplicate operator registration: #{operator} (#{existing} vs #{klass})" if existing

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
  end
end

require_relative 'matchers/abstract_matcher'
