# frozen_string_literal: true

module Mongory
  module Matchers
    # InMatcher implements the `$in` operator.
    #
    # It checks whether the record matches any value in the condition array.
    # If the record is an array, it succeeds if any item overlaps with the condition.
    # If the record is a single value (including `nil`), it matches if it is included in the condition.
    #
    # @example Match single value
    #   matcher = InMatcher.build([1, 2, 3])
    #   matcher.match?(2)        #=> true
    #   matcher.match?(5)        #=> false
    #
    # @example Match nil
    #   matcher = InMatcher.build([nil])
    #   matcher.match?(nil)      #=> true
    #
    # @example Match with array
    #   matcher = InMatcher.build([2, 4])
    #   matcher.match?([1, 2, 3])  #=> true
    #   matcher.match?([5, 6])     #=> false
    #
    # @see AbstractMatcher
    class InMatcher < AbstractMatcher
      # Matches if any element of the record appears in the condition array.
      # Converts record to an array before intersecting.
      #
      # @param record [Object] the record value to test
      # @return [Boolean] whether any values intersect
      def match(record)
        record = normalize(record)
        if record.is_a?(Array)
          is_present?(@condition & record)
        else
          @condition.include?(record)
        end
      end

      # Ensures the condition is an array.
      #
      # @raise [TypeError] if condition is not an array
      # @return [void]
      def check_validity!
        raise TypeError, '$in needs an array' unless @condition.is_a?(Array)
      end
    end
  end
end
