# frozen_string_literal: true

module Mongory
  module Matchers
    # GtMatcher implements the `$gt` (greater than) operator.
    #
    # It returns true if the record is strictly greater than the condition.
    #
    # Inherits core logic from AbstractMatcher, including
    # error handling and optional preprocessing.
    #
    # @example
    #   matcher = GtMatcher.build(10)
    #   matcher.match?(15)  #=> true
    #   matcher.match?(10)  #=> false
    #
    # @see AbstractMatcher
    class GtMatcher < AbstractMatcher
      # Creates a raw Proc that performs the greater-than comparison.
      # The Proc uses the `>` operator to compare values.
      #
      # @return [Proc] a Proc that performs the greater-than comparison
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record > condition
        rescue StandardError
          false
        end
      end
    end

    register(:gt, '$gt', GtMatcher)
  end
end
