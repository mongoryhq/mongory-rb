# frozen_string_literal: true

module Mongory
  module Matchers
    # GtMatcher implements the `$gt` (greater than) operator.
    #
    # It returns true if the record is strictly greater than the condition.
    #
    # Inherits core logic from AbstractOperatorMatcher, including
    # error handling and optional preprocessing.
    #
    # @example
    #   matcher = GtMatcher.build(10)
    #   matcher.match?(15)  #=> true
    #   matcher.match?(10)  #=> false
    #
    # @see AbstractOperatorMatcher
    class GtMatcher < AbstractOperatorMatcher
      # Returns the Ruby `>` operator symbol for comparison.
      #
      # @return [Symbol] the greater-than operator
      def operator
        :>
      end
    end
  end
end
