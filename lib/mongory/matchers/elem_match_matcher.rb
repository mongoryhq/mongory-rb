# frozen_string_literal: true

module Mongory
  module Matchers
    # ElemMatchMatcher implements the logic for Mongo-style `$elemMatch`.
    #
    # It is used to determine if *any* element in an array matches the given condition.
    #
    # This matcher delegates element-wise comparison to HashConditionMatcher,
    # allowing nested conditions to be applied recursively.
    #
    # Typically used internally by ArrayRecordMatcher when dealing with
    # non-indexed hash-style subconditions.
    #
    # @example
    #   matcher = ElemMatchMatcher.build({ status: 'active' })
    #   matcher.match?([{ status: 'inactive' }, { status: 'active' }]) #=> true
    #
    # @see HashConditionMatcher
    class ElemMatchMatcher < HashConditionMatcher
      # Matches true if any element in the array satisfies the condition.
      # Falls back to false if the input is not an array.

      alias_method :super_match, :match
      # @param collection [Object] the input to be tested
      # @return [Boolean] whether any element matches
      def match(collection)
        return false unless collection.is_a?(Array)

        collection.any? do |record|
          super_match(Mongory.data_converter.convert(record))
        end
      end

      # Creates a raw Proc that performs the element matching operation.
      # The Proc checks if any element in the array matches the condition.
      #
      # @return [Proc] a Proc that performs the element matching operation
      def raw_proc
        super_proc = super

        Proc.new do |collection|
          collection.any? do |record|
            super_proc.call(record)
          end
        end
      end

      # Ensures the condition is a Hash.
      #
      # @raise [Mongory::TypeError] if the condition is not a Hash
      # @return [void]
      def check_validity!
        raise TypeError, '$elemMatch needs a Hash.' unless @condition.is_a?(Hash)

        super
      end
    end

    register(:elem_match, '$elemMatch', ElemMatchMatcher)
  end
end
