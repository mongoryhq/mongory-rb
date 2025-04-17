# frozen_string_literal: true

module Mongory
  module Matchers
    # HashConditionMatcher is responsible for handling field-level query conditions.
    #
    # It receives a Hash of key-value pairs and delegates each one to an appropriate matcher
    # based on whether the key is a recognized operator or a data field path.
    #
    # Each subcondition is matched independently using the `:all?` strategy, meaning
    # all subconditions must match for the entire HashConditionMatcher to succeed.
    #
    # This matcher plays a central role in dispatching symbolic query conditions
    # to the appropriate field or operator matcher.
    #
    # @example
    #   matcher = HashConditionMatcher.build({ age: { :$gt => 30 }, active: true })
    #   matcher.match?(record) #=> true only if all subconditions match
    #
    # @see AbstractMultiMatcher
    class HashConditionMatcher < AbstractMultiMatcher
      enable_unwrap!
      # Constructs the appropriate submatcher for a key-value pair.
      # If the key is a registered operator, dispatches to the corresponding matcher.
      # Otherwise, assumes the key is a field path and uses FieldMatcher.

      # @see FieldMatcher
      # @see Matchers.lookup
      # @param key [String] the condition key (either an operator or field name)
      # @param value [Object] the condition value
      # @return [AbstractMatcher] a matcher instance
      def build_sub_matcher(key, value)
        case key
        when *Matchers::OPERATOR_TO_CLASS_MAPPING.keys
          Matchers.lookup(key).build(value)
        else
          FieldMatcher.build(key, value)
        end
      end

      # Specifies the matching strategy for all subconditions.
      # Uses `:all?`, meaning all conditions must be satisfied.
      #
      # @return [Symbol] the combining operator method
      def operator
        :all?
      end
    end
  end
end
