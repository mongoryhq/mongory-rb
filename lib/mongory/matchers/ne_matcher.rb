# frozen_string_literal: true

module Mongory
  module Matchers
    # NeMatcher implements the `$ne` (not equal) operator.
    #
    # It returns true if the record is *not equal* to the condition.
    #
    # This matcher inherits its logic from AbstractMatcher
    # and uses Ruby's `!=` operator for comparison.
    #
    # @example
    #   matcher = NeMatcher.build(42)
    #   matcher.match?(41)  #=> true
    #   matcher.match?(42)  #=> false
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
          record != condition
        end
      end
    end

    register(:ne, '$ne', NeMatcher)
  end
end
