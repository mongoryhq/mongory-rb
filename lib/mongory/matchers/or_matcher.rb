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
      # Constructs a HashConditionMatcher for each subcondition.
      # Conversion is disabled to avoid double-processing.

      # @see HashConditionMatcher
      # @param condition [Object] a subcondition to be wrapped
      # @return [HashConditionMatcher] a matcher for this condition
      def build_sub_matcher(condition)
        HashConditionMatcher.build(condition)
      end

      # Uses `:any?` to return true if any submatcher passes.
      #
      # @return [Symbol] the combining operator
      def operator
        :any?
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
  end
end
