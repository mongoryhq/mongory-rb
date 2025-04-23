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
        return FALSE_PROC if matchers.empty?

        combine_procs(*matchers.map(&:to_proc))
      end

      # Recursively combines multiple matcher procs with OR logic.
      # This method optimizes the combination of multiple matchers by building
      # a balanced tree of OR operations.
      #
      # @param left [Proc] The left matcher proc to combine
      # @param rest [Array<Proc>] The remaining matcher procs to combine
      # @return [Proc] A new proc that combines all matchers with OR logic
      # @example
      #   combine_procs(proc1, proc2, proc3)
      #   #=> proc { |record| proc1.call(record) || proc2.call(record) || proc3.call(record) }
      def combine_procs(left, *rest)
        return left if rest.empty?

        right = combine_procs(*rest)
        Proc.new do |record|
          left.call(record) || right.call(record)
        end
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
