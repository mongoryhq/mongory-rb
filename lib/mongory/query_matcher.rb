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
  class QueryMatcher < Matchers::LiteralMatcher
    # Initializes a new query matcher with the given condition.
    # The condition is converted using Mongory.condition_converter
    # before being passed to the parent matcher.
    #
    # @param condition [Hash<Symbol, Object>] a query condition using operator-style symbol keys,
    #   e.g. { :age.gt => 18 }, which will be parsed by `Mongory.condition_converter`.
    def initialize(condition)
      super(Mongory.condition_converter.convert(condition))
    end

    alias_method :super_match, :match

    # Matches the given record against the condition.
    # The record is first converted using Mongory.data_converter
    # to ensure consistent data types during comparison.
    #
    # @param record [Object] the raw input record (e.g., Hash or model object) to be matched.
    #   It will be converted internally using `Mongory.data_converter`.
    # @return [Boolean] whether the record satisfies the condition
    def match(record)
      super_match(Mongory.data_converter.convert(record))
    end

    # Returns a Proc that can be used for fast matching.
    # The Proc handles errors gracefully by returning false
    # if any error occurs during matching.
    #
    # @return [Proc] a callable that takes a record and returns a boolean
    def raw_proc
      super_proc = super

      Proc.new do |record|
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
