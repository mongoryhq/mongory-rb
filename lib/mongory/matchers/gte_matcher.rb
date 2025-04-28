# frozen_string_literal: true

module Mongory
  module Matchers
    # GteMatcher implements the `$gte` (greater than or equal) operator.
    #
    # It returns true if the record is greater than or equal to the condition value.
    #
    # Inherits comparison logic and error safety from AbstractMatcher.
    #
    # @example
    #   matcher = GteMatcher.build(10)
    #   matcher.match?(10)  #=> true
    #   matcher.match?(11)  #=> true
    #   matcher.match?(9)   #=> false
    #
    # @see AbstractMatcher
    class GteMatcher < AbstractMatcher
      # Creates a raw Proc that performs the greater-than-or-equal comparison.
      # The Proc uses the `>=` operator to compare values.
      #
      # @return [Proc] A proc that performs greater-than-or-equal comparison with error handling
      # @note The proc includes error handling for invalid comparisons
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record >= condition
        rescue StandardError
          false
        end
      end

      def priority
        3
      end
    end

    register(:gte, '$gte', GteMatcher)
  end
end
