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

      # Performs the logical AND operation on all subconditions.
      # Returns true only if all subconditions match the record.
      #
      # @param record [Object] the record to match against
      # @return [Boolean] true if all subconditions match, false otherwise
      def match(record)
        matchers.all? do |matcher|
          matcher.match(record)
        end
      end

      # Creates a raw Proc that performs the AND operation.
      # The Proc combines all subcondition Procs and returns true only if all match.
      #
      # @return [Proc] a Proc that performs the AND operation
      def raw_proc
        matcher_procs = matchers.map(&:to_proc)
        Proc.new do |record|
          matcher_procs.all? do |matcher_proc|
            matcher_proc.call(record)
          end
        end
      end

      # Returns the flattened list of all matchers from each subcondition.
      #
      # Each condition is passed to a HashConditionMatcher, then recursively flattened.
      # All matchers are then deduplicated using `uniq_key`.
      #
      # @return [Array<AbstractMatcher>]
      # @see AbstractMatcher#uniq_key
      define_instance_cache_method(:matchers) do
        @condition.flat_map do |condition|
          HashConditionMatcher.new(condition, context: @context).matchers
        end.uniq(&:uniq_key)
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

    register(:and, '$and', AndMatcher)
  end
end
