# frozen_string_literal: true

module Mongory
  module Matchers
    # EqMatcher matches values using the equality operator `==`.
    #
    # It inherits from AbstractMatcher and defines its operator as `:==`.
    #
    # Used for conditions like:
    # - { age: { '$eq' => 30 } }
    # - { name: "Alice" } (implicit fallback)
    #
    # This matcher supports any Ruby object that implements `#==`.
    #
    # @example
    #   matcher = EqMatcher.build(42)
    #   matcher.match?(42)       #=> true
    #   matcher.match?("42")     #=> false
    #
    # @note This matcher is also used as the fallback for non-operator literal values,
    #       such as `{ name: "Alice" }`, when no other specialized matcher is applicable.
    #
    # @note Equality behavior depends on how `==` is implemented for the given objects.
    #
    # @see AbstractMatcher
    class EqMatcher < AbstractMatcher
      # Creates a raw Proc that performs the equality check.
      # The Proc uses the `==` operator to compare values.
      #
      # @return [Proc] a Proc that performs the equality check
      def raw_proc
        condition = @condition

        Proc.new do |record|
          record == condition
        end
      end
    end

    register(:eq, '$eq', EqMatcher)
  end
end
