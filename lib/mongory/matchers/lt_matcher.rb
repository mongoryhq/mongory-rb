# frozen_string_literal: true

module Mongory
  module Matchers
    # LtMatcher implements the `$lt` (less than) operator.
    #
    # It returns true if the record is strictly less than the condition value.
    #
    # This matcher inherits from AbstractMatcher and uses the `<` operator.
    #
    # @example
    #   matcher = LtMatcher.build(10)
    #   matcher.match?(9)    #=> true
    #   matcher.match?(10)   #=> false
    #   matcher.match?(11)   #=> false
    #
    # @see AbstractMatcher
    class LtMatcher < AbstractMatcher
      # Creates a raw Proc that performs the less-than comparison.
      # The Proc uses the `<` operator to compare values.
      #
      # @return [Proc] A proc that performs less-than comparison with error handling
      # @note The proc includes error handling for invalid comparisons
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record < condition
        rescue StandardError
          false
        end
      end

      def priority
        3
      end
    end

    register(:lt, '$lt', LtMatcher)
  end
end
