# frozen_string_literal: true

module Mongory
  module Matchers
    # EveryMatcher implements the logic for Mongo-style `$every` which is not really support in MongoDB.
    #
    # It is used to determine if *all* element in an array matches the given condition.
    #
    # This matcher delegates element-wise comparison to HashConditionMatcher,
    # allowing nested conditions to be applied recursively.
    #
    # @example
    #   matcher = EveryMatcher.build({ status: 'active' })
    #   matcher.match?([{ status: 'inactive' }, { status: 'active' }]) #=> false
    #
    # @see HashConditionMatcher
    class EveryMatcher < HashConditionMatcher
      # Creates a raw Proc that performs the element matching operation.
      # The Proc checks if all elements in the array match the condition.
      #
      # @return [Proc] A proc that performs element matching with context awareness
      # @note The proc includes error handling and context-based record conversion
      def raw_proc
        super_proc = super
        need_convert = @context.need_convert
        data_converter = Mongory.data_converter

        Proc.new do |collection|
          next false unless collection.is_a?(Array)
          next false if collection.empty?

          collection.all? do |record|
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
        raise TypeError, '$every needs a Hash.' unless @condition.is_a?(Hash)

        super
      end
    end

    register(:every, '$every', EveryMatcher)
  end
end
