# frozen_string_literal: true

module Mongory
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
      # Creates a raw Proc that performs the not-matching operation.
      # The Proc inverts the result of the wrapped matcher.
      #
      # @return [Proc] A proc that performs not-matching
      def raw_proc
        super_proc = super

        Proc.new do |record|
          !super_proc.call(record)
        end
      end
    end

    register(:not, '$not', NotMatcher)
  end
end
