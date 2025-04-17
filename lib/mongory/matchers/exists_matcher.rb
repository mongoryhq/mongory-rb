# frozen_string_literal: true

module Mongory
  module Matchers
    # ExistsMatcher implements the `$exists` operator, which checks whether a key exists.
    #
    # It transforms the presence (or absence) of a field into a boolean value,
    # then compares it to the condition using the `==` operator.
    #
    # This matcher ensures the condition is strictly a boolean (`true` or `false`).
    #
    # @example
    #   matcher = ExistsMatcher.build(true)
    #   matcher.match?(42)              #=> true
    #   matcher.match?(KEY_NOT_FOUND)   #=> false
    #
    #   matcher = ExistsMatcher.build(false)
    #   matcher.match?(KEY_NOT_FOUND)   #=> true
    #
    # @see AbstractOperatorMatcher
    class ExistsMatcher < AbstractOperatorMatcher
      # Converts the raw record value into a boolean indicating presence.
      #
      # @param record [Object] the value associated with the field
      # @return [Boolean] true if the key exists, false otherwise
      def preprocess(record)
        record != KEY_NOT_FOUND
      end

      # Uses Ruby's equality operator to compare presence against expected boolean.
      #
      # @return [Symbol] the comparison operator
      def operator
        :==
      end

      # Ensures that the condition value is a valid boolean.
      #
      # @raise [TypeError] if condition is not true or false
      # @return [void]
      def check_validity!
        raise TypeError, '$exists needs a boolean' unless BOOLEAN_VALUES.include?(@condition)
      end
    end
  end
end
