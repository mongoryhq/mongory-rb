# frozen_string_literal: true

module Mongory
  module Matchers
    # NinMatcher implements the `$nin` (not in) operator.
    #
    # It succeeds only if the record does not match any value in the condition array.
    # If the record is an array, it fails if any element overlaps with the condition.
    # If the record is a single value (including `nil`), it fails if it is included in the condition.
    #
    # @example Match single value
    #   matcher = NinMatcher.build([1, 2, 3])
    #   matcher.match?(4)        #=> true
    #   matcher.match?(2)        #=> false
    #
    # @example Match nil
    #   matcher = NinMatcher.build([nil])
    #   matcher.match?(nil)      #=> false
    #
    # @example Match with array
    #   matcher = NinMatcher.build([2, 4])
    #   matcher.match?([1, 3, 5])  #=> true
    #   matcher.match?([4, 5])     #=> false
    #
    # @see AbstractMatcher
    class NinMatcher < AbstractMatcher
      # Matches true if the record has no elements in common with the condition array.
      #
      # @param record [Object] the value to be tested
      # @return [Boolean] whether the record is disjoint from the condition array
      def match(record)
        record = normalize(record)
        if record.is_a?(Array)
          is_blank?(@condition & record)
        else
          !@condition.include?(record)
        end
      end

      # Ensures the condition is a valid array.
      #
      # @raise [TypeError] if the condition is not an array
      # @return [void]
      def check_validity!
        raise TypeError, '$nin needs an array' unless @condition.is_a?(Array)
      end
    end
  end
end
