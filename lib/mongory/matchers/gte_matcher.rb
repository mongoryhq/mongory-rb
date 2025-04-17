# frozen_string_literal: true

module Mongory
  module Matchers
    # GteMatcher implements the `$gte` (greater than or equal) operator.
    #
    # It returns true if the record is greater than or equal to the condition value.
    #
    # Inherits comparison logic and error safety from AbstractOperatorMatcher.
    #
    # @example
    #   matcher = GteMatcher.build(10)
    #   matcher.match?(10)  #=> true
    #   matcher.match?(11)  #=> true
    #   matcher.match?(9)   #=> false
    #
    # @see AbstractOperatorMatcher
    class GteMatcher < AbstractOperatorMatcher
      # Returns the Ruby `>=` operator symbol for comparison.
      #
      # @return [Symbol] the greater-than-or-equal operator
      def operator
        :>=
      end
    end
  end
end
