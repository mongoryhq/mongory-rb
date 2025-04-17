# frozen_string_literal: true

module Mongory
  # The Mongory module provides a set of matchers for querying and filtering data.
  module Matchers
    # LteMatcher implements the `$lte` (less than or equal to) operator.
    #
    # It returns true if the record is less than or equal to the condition value.
    #
    # This matcher inherits from AbstractOperatorMatcher and uses the `<=` operator.
    #
    # @example
    #   matcher = LteMatcher.build(10)
    #   matcher.match?(9)    #=> true
    #   matcher.match?(10)   #=> true
    #   matcher.match?(11)   #=> false
    #
    # @see AbstractOperatorMatcher
    class LteMatcher < AbstractOperatorMatcher
      # Returns the Ruby `<=` operator symbol for comparison.
      #
      # @return [Symbol] the less-than-or-equal operator
      def operator
        :<=
      end
    end

    register(:lte, '$lte', LteMatcher)
  end
end
