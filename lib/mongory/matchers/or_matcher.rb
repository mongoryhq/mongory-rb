# frozen_string_literal: true

module Mongory
  module Matchers
    # OrMatcher implements the `$or` logical operator.
    #
    # It evaluates an array of subconditions and returns true
    # if *any one* of them matches. For empty conditions, it returns false
    # (using FALSE_PROC).
    #
    # Each subcondition is handled by a HashConditionMatcher with conversion disabled,
    # since the parent matcher already manages data conversion.
    #
    # This matcher inherits submatcher dispatch and evaluation logic
    # from AbstractMultiMatcher.
    #
    # @example
    #   matcher = OrMatcher.build([
    #     { age: { :$lt => 18 } },
    #     { admin: true }
    #   ])
    #   matcher.match?(record) #=> true if either condition matches
    #
    # @example Empty conditions
    #   matcher = OrMatcher.build([])
    #   matcher.match?(record) #=> false (uses FALSE_PROC)
    #
    # @see AbstractMultiMatcher
    class OrMatcher < AbstractMultiMatcher
      enable_unwrap!

      # Creates a raw Proc that performs the or-matching operation.
      # The Proc combines all submatcher Procs and returns true if any match.
      # For empty conditions, returns FALSE_PROC.
      #
      # @return [Proc] a Proc that performs the or-matching operation
      def raw_proc
        combine_procs_with_or(*matchers.map(&:to_proc))
      end

      # Builds an array of matchers from the subconditions.
      # Each subcondition is wrapped in a HashConditionMatcher.
      #
      # @return [Array<AbstractMatcher>] array of submatchers
      define_instance_cache_method(:matchers) do
        @condition.map do |condition|
          HashConditionMatcher.build(condition, context: @context)
        end
      end

      # Ensures the condition is an array of hashes.
      #
      # @raise [Mongory::TypeError] if not valid
      # @return [void]
      def check_validity!
        raise TypeError, '$or needs an array' unless @condition.is_a?(Array)

        @condition.each do |sub_condition|
          raise TypeError, '$or needs an array of hash' unless sub_condition.is_a?(Hash)
        end

        super
      end
    end

    register(:or, '$or', OrMatcher)
  end
end
