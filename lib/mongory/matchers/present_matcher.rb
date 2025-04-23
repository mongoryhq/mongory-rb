# frozen_string_literal: true

module Mongory
  module Matchers
    # PresentMatcher implements the `$present` operator.
    #
    # It returns true if the record value is considered "present"
    # (i.e., not nil, not empty, not KEY_NOT_FOUND), and matches
    # the expected boolean condition.
    #
    # This is similar to `$exists`, but evaluates truthiness
    # of the value instead of mere existence.
    #
    # @example
    #   matcher = PresentMatcher.build(true)
    #   matcher.match?('hello')     #=> true
    #   matcher.match?(nil)         #=> false
    #   matcher.match?([])          #=> false
    #
    #   matcher = PresentMatcher.build(false)
    #   matcher.match?(nil)         #=> true
    #
    # @see AbstractMatcher
    class PresentMatcher < AbstractMatcher
      # Creates a raw Proc that performs the presence check.
      # The Proc checks if the record's presence matches the condition.
      #
      # @return [Proc] a Proc that performs the presence check
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record = nil if record == KEY_NOT_FOUND
          is_present?(record) == condition
        end
      end

      # Ensures that the condition value is a boolean.
      #
      # @raise [TypeError] if condition is not true or false
      # @return [void]
      def check_validity!
        return if [true, false].include?(@condition)

        raise TypeError, '$present needs a boolean'
      end
    end

    register(:present, '$present', PresentMatcher)
  end
end
