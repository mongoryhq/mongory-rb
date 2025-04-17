# frozen_string_literal: true

module Mongory
  module Matchers
    # AndMatcher implements the `$and` logical operator.
    #
    # It evaluates an array of subconditions and returns true only if *all* of them match.
    #
    # Unlike other matchers, AndMatcher flattens the underlying matcher tree by
    # delegating each subcondition to a `HashConditionMatcher`, and further extracting
    # all inner matchers. Duplicate matchers are deduplicated by `uniq_key`.
    #
    # This allows the matcher trace (`.explain`) to render as a flat list of independent conditions.
    #
    # @example
    #   matcher = AndMatcher.build([
    #     { age: { :$gte => 18 } },
    #     { name: /foo/ }
    #   ])
    #   matcher.match?(record) #=> true if both match
    #
    # @see AbstractMultiMatcher
    class AndMatcher < AbstractMultiMatcher
      # Constructs a HashConditionMatcher for each subcondition.
      # Conversion is disabled to avoid double-processing.
      enable_unwrap!

      # Returns the flattened list of all matchers from each subcondition.
      #
      # Each condition is passed to a HashConditionMatcher, then recursively flattened.
      # All matchers are then deduplicated using `uniq_key`.
      #
      # @return [Array<AbstractMatcher>]
      # @see AbstractMatcher#uniq_key
      define_instance_cache_method(:matchers) do
        @condition.flat_map do |condition|
          HashConditionMatcher.new(condition).matchers
        end.uniq(&:uniq_key)
      end

      # Combines submatcher results using `:all?`.
      #
      # @return [Symbol]
      def operator
        :all?
      end

      # Ensures the condition is an array of hashes.
      #
      # @raise [Mongory::TypeError] if not valid
      # @return [void]
      def check_validity!
        raise TypeError, '$and needs an array' unless @condition.is_a?(Array)

        @condition.each do |sub_condition|
          raise TypeError, '$and needs an array of hash' unless sub_condition.is_a?(Hash)
        end

        super
      end
    end
  end
end
