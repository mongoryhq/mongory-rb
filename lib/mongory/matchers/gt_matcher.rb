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
    class GtMatcher < AbstractMatcher
      # Checks if the record is greater than the condition.
      #
      # @param record [Object] the value to compare against
      # @return [Boolean] true if the record is greater than the condition
      def match(record)
        record > @condition
      end

      # Creates a raw Proc that performs the greater-than comparison.
      # The Proc uses the `>` operator to compare values.
      #
      # @return [Proc] a Proc that performs the greater-than comparison
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record > condition
        end
      end
    end

    register(:gt, '$gt', GtMatcher)
  end
end
