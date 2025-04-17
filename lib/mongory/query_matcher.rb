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
  #
  # @example
  #   matcher = QueryMatcher.build({ :age.gte => 18 })
  #   matcher.match?(record)
  #
  # @see Matchers::LiteralMatcher
  # @see Converters::ConditionConverter
  class QueryMatcher < Matchers::LiteralMatcher
    # @param condition [Hash] the raw user query
    def initialize(condition)
      super(Mongory.condition_converter.convert(condition))
    end

    # Matches the given record against the condition.
    #
    # @param record [Object] the record to be matched
    # @return [Boolean] whether the record satisfies the condition
    def match(record)
      super(Mongory.data_converter.convert(record))
    end

    # Renders the full matcher tree for the current query.
    #
    # This method is intended to be the public entry point for rendering
    # the matcher tree. It does not accept any arguments and internally
    # handles rendering via the configured pretty-print logic.
    #
    # Subclasses or internal matchers should implement their own
    # `#render_tree(prefix, is_last:)` for internal recursion.
    #
    # @return [void]
    def render_tree
      super
    end
  end
end
