# frozen_string_literal: true

module Mongory
  module Matchers
    # NeMatcher implements the `$ne` (not equal) operator.
    #
    # It returns true if the record is *not equal* to the condition.
    # If the record is an `Array`, it returns false if either the array itself
    # equals the condition or any element in the array equals the condition.
    #
    # @example
    #   matcher = NeMatcher.build(42)
    #   matcher.match?(41)       #=> true
    #   matcher.match?(42)       #=> false
    #   matcher.match?([10, 42]) #=> false
    #   matcher.match?([10, 20]) #=> true
    #
    # @see AbstractMatcher
    class NeMatcher < AbstractMatcher
      # Creates a raw Proc that performs the not-equal comparison.
      # The Proc uses the `!=` operator to compare values.
      #
      # @return [Proc] A proc that performs not-equal comparison
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record != condition && !(record.is_a?(Array) && record.include?(condition))
        end
      end

      def priority
        1
      end
    end

    register(:ne, '$ne', NeMatcher)
  end
end
