# frozen_string_literal: true

module Mongory
  module Matchers
    # LteMatcher implements the `$lte` (less than or equal to) operator.
    #
    # It returns true if the record is less than or equal to the condition value.
    #
    # This matcher inherits from AbstractMatcher and uses the `<=` operator.
    #
    # @example
    #   matcher = LteMatcher.build(10)
    #   matcher.match?(9)    #=> true
    #   matcher.match?(10)   #=> true
    #   matcher.match?(11)   #=> false
    #
    # @see AbstractMatcher
    class LteMatcher < AbstractMatcher
      # Creates a raw Proc that performs the less-than-or-equal comparison.
      # The Proc uses the `<=` operator to compare values.
      #
      # @return [Proc] a Proc that performs the less-than-or-equal comparison
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record <= condition
        rescue StandardError
          false
        end
      end
    end

    register(:lte, '$lte', LteMatcher)
  end
end
