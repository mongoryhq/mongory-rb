# frozen_string_literal: true

module Mongory
  module Matchers
    # LtMatcher implements the `$lt` (less than) operator.
    #
    # It returns true if the record is strictly less than the condition value.
    #
    # This matcher inherits from AbstractOperatorMatcher and uses the `<` operator.
    #
    # @example
    #   matcher = LtMatcher.build(10)
    #   matcher.match?(9)    #=> true
    #   matcher.match?(10)   #=> false
    #   matcher.match?(11)   #=> false
    #
    # @see AbstractOperatorMatcher
    class LtMatcher < AbstractOperatorMatcher
      # Returns the Ruby `<` operator symbol for comparison.
      #
      # @return [Symbol] the less-than operator
      def operator
        :<
      end
    end
  end
end
