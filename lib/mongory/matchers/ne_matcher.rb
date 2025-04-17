# frozen_string_literal: true

module Mongory
  module Matchers
    # NeMatcher implements the `$ne` (not equal) operator.
    #
    # It returns true if the record is *not equal* to the condition.
    #
    # This matcher inherits its logic from AbstractOperatorMatcher
    # and uses Ruby's `!=` operator for comparison.
    #
    # @example
    #   matcher = NeMatcher.build(42)
    #   matcher.match?(41)  #=> true
    #   matcher.match?(42)  #=> false
    #
    # @see AbstractOperatorMatcher
    class NeMatcher < AbstractOperatorMatcher
      # Returns the Ruby `!=` operator symbol for comparison.
      #
      # @return [Symbol] the not-equal operator
      def operator
        :!=
      end
    end
  end
end
