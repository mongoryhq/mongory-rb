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
    class LtMatcher < AbstractMatcher
      # Checks if the record is less than the condition.
      #
      # @param record [Object] the value to compare against
      # @return [Boolean] true if the record is less than the condition
      def match(record)
        record < @condition
      end

      # Creates a raw Proc that performs the less-than comparison.
      # The Proc uses the `<` operator to compare values.
      #
      # @return [Proc] a Proc that performs the less-than comparison
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record < condition
        end
      end
    end

    register(:lt, '$lt', LtMatcher)
  end
end
