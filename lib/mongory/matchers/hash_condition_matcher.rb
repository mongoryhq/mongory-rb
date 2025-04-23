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

      # Creates a raw Proc that performs the hash condition matching operation.
      # The Proc combines all submatcher Procs and returns true only if all match.
      #
      # @return [Proc] a Proc that performs the hash condition matching operation
      def raw_proc
        return TRUE_PROC if matchers.empty?

        combine_procs(*matchers.map(&:to_proc))
      end

      def combine_procs(left, *rest)
        return left if rest.empty?

        right = combine_procs(*rest)
        Proc.new do |record|
          left.call(record) && right.call(record)
        end
      end

      # Constructs the appropriate submatcher for a key-value pair.
      # If the key is a registered operator, dispatches to the corresponding matcher.
      # Otherwise, assumes the key is a field path and uses FieldMatcher.
      #
      # @return [Array<AbstractMatcher>] list of sub-matchers
      # @see FieldMatcher
      # @see Matchers.lookup
      define_instance_cache_method(:matchers) do
        @condition.map do |key, value|
          case key
          when *Matchers.operators
            # If the key is a recognized operator, use the corresponding matcher
            # to handle the value.
            # This allows for nested conditions like { :$and => [{ age: { :$gt => 30 } }] }
            # or { :$or => [{ name: 'John' }, { age: { :$lt => 25 } }] }
            # The operator matcher is built using the value.
            Matchers.lookup(key).build(value, context: @context)
          else
            FieldMatcher.build(key, value, context: @context)
          end
        end
      end
    end
  end
end
