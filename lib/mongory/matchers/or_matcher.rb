# frozen_string_literal: true

module Mongory
  module Matchers
    # OrMatcher implements the `$or` logical operator.
    #
    # It evaluates an array of subconditions and returns true
    # if *any one* of them matches.
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
    # @see AbstractMultiMatcher
    class OrMatcher < AbstractMultiMatcher
      enable_unwrap!

      # Creates a raw Proc that performs the or-matching operation.
      # The Proc combines all submatcher Procs and returns true if any match.
      #
      # @return [Proc] a Proc that performs the or-matching operation
      def raw_proc
        return FALSE_PROC if matchers.empty?

        combine_procs(*matchers.map(&:to_proc))
      end

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
        @condition.map do |sub_condition|
          # Use HashConditionMatcher with conversion disabled
          HashConditionMatcher.build(sub_condition, context: @context)
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
