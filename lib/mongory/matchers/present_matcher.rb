# frozen_string_literal: true

module Mongory
  module Matchers
    # PresentMatcher implements the `$present` operator.
    #
    # It returns true if the record value is considered "present"
    # (i.e., not nil, not empty, not KEY_NOT_FOUND), and matches
    # the expected boolean condition.
    #
    # This is similar to `$exists`, but evaluates truthiness
    # of the value instead of mere existence.
    #
    # @example
    #   matcher = PresentMatcher.build(true)
    #   matcher.match?('hello')     #=> true
    #   matcher.match?(nil)         #=> false
    #   matcher.match?([])          #=> false
    #
    #   matcher = PresentMatcher.build(false)
    #   matcher.match?(nil)         #=> true
    #
    # @see AbstractOperatorMatcher
    class PresentMatcher < AbstractOperatorMatcher
      # Transforms the record into a boolean presence flag
      # before applying comparison.
      #
      # @param record [Object] the original value
      # @return [Boolean] whether the value is present
      def preprocess(record)
        is_present?(super)
      end

      # Uses Ruby `==` to compare the presence result to the expected boolean.
      #
      # @return [Symbol] the equality operator
      def operator
        :==
      end

      # Ensures that the condition value is a boolean.
      #
      # @raise [TypeError] if condition is not true or false
      # @return [void]
      def check_validity!
        raise TypeError, '$present needs a boolean' unless BOOLEAN_VALUES.include?(@condition)
      end
    end
  end
end
