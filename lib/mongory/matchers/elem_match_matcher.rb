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
      # Creates a raw Proc that performs the element matching operation.
      # The Proc checks if any element in the array matches the condition.
      #
      # @return [Proc] a Proc that performs the element matching operation
      def raw_proc
        super_proc = super
        need_convert = @context.need_convert
        data_converter = Mongory.data_converter

        Proc.new do |collection|
          collection.any? do |record|
            record = data_converter.convert(record) if need_convert
            super_proc.call(record)
          end
        end
      end

      def priority
        3 + super
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
