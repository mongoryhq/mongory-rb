# frozen_string_literal: true

module Mongory
  # The Mongory module provides a set of matchers for querying and filtering data.
  module Matchers
    # NotMatcher implements the `$not` logical operator.
    #
    # It returns true if the wrapped matcher fails, effectively inverting the result.
    #
    # It delegates to LiteralMatcher and simply negates the outcome.
    #
    # This allows constructs like:
    #   { age: { :$not => { :$gte => 30 } } }
    #
    # @example
    #   matcher = NotMatcher.build({ :$gte => 10 })
    #   matcher.match?(5)    #=> true
    #   matcher.match?(15)   #=> false
    #
    # @see LiteralMatcher
    class NotMatcher < LiteralMatcher
      # Inverts the result of LiteralMatcher#match.
      #
      # @param record [Object] the value to test
      # @return [Boolean] whether the negated condition is satisfied
      def match(record)
        !super(record)
      end
    end

    register(:not, '$not', NotMatcher)
  end
end
