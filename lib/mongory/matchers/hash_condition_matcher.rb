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
    # For empty conditions, it returns true (using TRUE_PROC).
    #
    # This matcher plays a central role in dispatching symbolic query conditions
    # to the appropriate field or operator matcher.
    #
    # @example Basic field matching
    #   matcher = HashConditionMatcher.build({ age: { :$gt => 30 }, active: true })
    #   matcher.match?(record) #=> true only if all subconditions match
    #
    # @example Empty conditions
    #   matcher = HashConditionMatcher.build({})
    #   matcher.match?(record) #=> true (uses TRUE_PROC)
    #
    # @see AbstractMultiMatcher
    class HashConditionMatcher < AbstractMultiMatcher
      enable_unwrap!

      # Creates a raw Proc that performs the hash condition matching operation.
      # The Proc combines all submatcher Procs and returns true only if all match.
      # For empty conditions, returns TRUE_PROC.
      #
      # @return [Proc] a Proc that performs the hash condition matching operation
      def raw_proc
        combine_procs_with_and(*matchers.map(&:to_proc))
      end

      # Returns the list of matchers for each key-value pair in the condition.
      #
      # For each pair:
      # - If the key is a registered operator, uses the corresponding matcher
      # - Otherwise, wraps the value in a FieldMatcher for field path matching
      #
      # @return [Array<AbstractMatcher>] List of matchers for each condition
      define_instance_cache_method(:matchers) do
        @condition.map do |key, value|
          if (matcher_class = Matchers.lookup(key))
            matcher_class.build(value, context: @context)
          else
            FieldMatcher.build(key, value, context: @context)
          end
        end
      end

      def check_validity!
        return super if @condition.is_a?(Hash)

        raise TypeError, 'condition needs a Hash.'
      end
    end
  end
end
