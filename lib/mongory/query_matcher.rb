# frozen_string_literal: true

require_relative 'utils'

module Mongory
  # The top-level matcher for compiled query conditions.
  #
  # Delegates to {Matchers::LiteralMatcher} after transforming input
  # via {Converters::ConditionConverter}.
  #
  # Typically used internally by `QueryBuilder`.
  #
  # Conversion via Mongory.data_converter is applied to the record
  # before matching to ensure consistent data types.
  #
  # @example Basic matching
  #   matcher = QueryMatcher.new({ :age.gte => 18 })
  #   matcher.match?(record) # => true/false
  #
  # @example Complex condition
  #   matcher = QueryMatcher.new({
  #     :age.gte => 18,
  #     :$or => [
  #       { :name => /J/ },
  #       { :name.eq => 'Bob' }
  #     ]
  #   })
  #
  # @see Matchers::LiteralMatcher
  # @see Converters::ConditionConverter
  class QueryMatcher < Matchers::HashConditionMatcher
    # Initializes a new query matcher with the given condition.
    # The condition is converted using Mongory.condition_converter
    # before being passed to the parent matcher.
    #
    # @param condition [Hash<Symbol, Object>] a query condition using operator-style symbol keys,
    #   e.g. { :age.gt => 18 }, which will be parsed by `Mongory.condition_converter`.
    # @param context [Context] The query context containing configuration and current record
    # @option context [Hash] :config The query configuration
    # @option context [Object] :current_record The current record being processed
    # @option context [Boolean] :need_convert Whether the record needs to be converted
    def initialize(condition, context: Utils::Context.new)
      super(Mongory.condition_converter.convert(condition), context: context)
    end

    # Returns a Proc that can be used for fast matching.
    # The Proc converts the record using Mongory.data_converter
    # and delegates to the superclass's raw_proc.
    #
    # @return [Proc] A proc that performs query matching with context awareness
    # @note The proc includes error handling and context-based record conversion
    def raw_proc
      super_proc = super
      need_convert = @context.need_convert
      data_converter = Mongory.data_converter

      Proc.new do |record|
        record = data_converter.convert(record) if need_convert
        super_proc.call(record)
      rescue StandardError
        false
      end
    end

    # Renders the full matcher tree for the current query.
    # This method is intended to be the public entry point for rendering
    # the matcher tree. It does not accept any arguments and internally
    # handles rendering via the configured pretty-print logic.
    #
    # Subclasses or internal matchers should implement their own
    # `#render_tree(prefix, is_last:)` for internal recursion.
    #
    # @return [void]
    # @see Matchers::LiteralMatcher#render_tree
    def render_tree
      super
    end

    # Prepares the query for execution by ensuring all necessary matchers are initialized.
    # This is called before query execution to avoid premature matcher tree construction.
    #
    # @return [void]
    alias_method :prepare_query, :check_validity!

    # Overrides the parent class's check_validity! to prevent premature matcher tree construction.
    # This matcher does not require validation, so this is a no-op.
    #
    # @return [void]
    def check_validity!
      # No-op for this matcher
    end
  end
end
