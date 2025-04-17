# frozen_string_literal: true

module Mongory
  module Matchers
    # AbstractOperatorMatcher is a base class for matchers that apply a binary
    # operator (e.g., `==`, `<`, `>` etc.) between the record and the condition.
    #
    # This class assumes that the match logic consists of:
    #   preprocess(record).send(operator, condition)
    # and provides a fallback behavior for invalid comparisons.
    #
    # Subclasses must implement `#operator` and may override `#preprocess`
    # to normalize or cast the record before comparison.
    #
    # @abstract
    # @see AbstractMatcher
    class AbstractOperatorMatcher < AbstractMatcher
      # A list of Boolean values used for type guarding in some subclasses.
      BOOLEAN_VALUES = [true, false].freeze

      # Applies the binary operator to the preprocessed record and condition.
      # If an error is raised (e.g., undefined comparison), the match fails.
      #
      # @param record [Object] the input record to test
      # @return [Boolean] the result of record <operator> condition
      def match(record)
        preprocess(record).send(operator, @condition)
      end

      # Hook for subclasses to transform the record before comparison.
      # Default behavior normalizes KEY_NOT_FOUND to nil.
      #
      # @param record [Object] the raw record value
      # @return [Object] the transformed value
      def preprocess(record)
        normalize(record)
      end

      # Returns the Ruby operator symbol to be used in comparison.
      # Must be implemented by subclasses (e.g., :==, :<, :>=)
      #
      # @return [Symbol] the comparison operator
      def operator; end
    end
  end
end
