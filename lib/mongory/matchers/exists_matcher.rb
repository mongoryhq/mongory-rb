# frozen_string_literal: true

module Mongory
  module Matchers
    # ExistsMatcher implements the `$exists` operator, which checks whether a key exists.
    #
    # It transforms the presence (or absence) of a field into a boolean value,
    # then compares it to the condition using the `==` operator.
    #
    # This matcher ensures the condition is strictly a boolean (`true` or `false`).
    #
    # @example
    #   matcher = ExistsMatcher.build(true)
    #   matcher.match?(42)              #=> true
    #   matcher.match?(KEY_NOT_FOUND)   #=> false
    #
    #   matcher = ExistsMatcher.build(false)
    #   matcher.match?(KEY_NOT_FOUND)   #=> true
    #
    # @see AbstractMatcher
    class ExistsMatcher < AbstractMatcher
      # Creates a raw Proc that performs the existence check.
      # The Proc checks if the record exists and compares it to the condition.
      #
      # @return [Proc] A proc that performs existence check with error handling
      def raw_proc
        condition = @condition

        Proc.new do |record|
          # Check if the record is nil or KEY_NOT_FOUND
          # and compare it to the condition.
          (record != KEY_NOT_FOUND) == condition
        end
      end

      # Ensures that the condition value is a valid boolean.
      #
      # @raise [TypeError] if condition is not true or false
      # @return [void]
      def check_validity!
        return if [true, false].include?(@condition)

        raise TypeError, "$exists needs a boolean, but got #{@condition.inspect}"
      end
    end

    register(:exists, '$exists', ExistsMatcher)
  end
end
