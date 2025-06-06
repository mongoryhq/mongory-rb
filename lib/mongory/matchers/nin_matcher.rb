# frozen_string_literal: true

module Mongory
  module Matchers
    # NinMatcher implements the `$nin` (not in) operator.
    #
    # It succeeds only if the record does not match any value in the condition array.
    # If the record is an array, it fails if any element overlaps with the condition.
    # If the record is a single value (including `nil`), it fails if it is included in the condition.
    #
    # @example Match single value
    #   matcher = NinMatcher.build([1, 2, 3])
    #   matcher.match?(4)        #=> true
    #   matcher.match?(2)        #=> false
    #
    # @example Match nil
    #   matcher = NinMatcher.build([nil])
    #   matcher.match?(nil)      #=> false
    #
    # @example Match with array
    #   matcher = NinMatcher.build([2, 4])
    #   matcher.match?([1, 3, 5])  #=> true
    #   matcher.match?([4, 5])     #=> false
    #
    # @see AbstractMatcher
    class NinMatcher < AbstractMatcher
      def self.build(condition, *args)
        return super unless condition.is_a?(Range)

        end_op = condition.exclude_end? ? '$gte' : '$gt'
        head, tail = [condition.first, condition.last].sort
        OrMatcher.build([{ '$lt' => head }, { end_op => tail }], *args)
      end

      # Creates a raw Proc that performs the not-in matching operation.
      # The Proc checks if the record has no elements in common with the condition array.
      #
      # @return [Proc] A proc that performs not-in matching
      def raw_proc
        condition = Set.new(@condition)

        Proc.new do |record|
          if record.is_a?(Array)
            is_blank?(condition & record)
          else
            !condition.include?(record)
          end
        end
      end

      def priority
        1 + Math.log(@condition.size + 1, 1.5)
      end

      # Ensures the condition is a valid array or range.
      #
      # @raise [TypeError] if the condition is not an array nor a range
      # @return [void]
      def check_validity!
        return if @condition.is_a?(Array)

        raise TypeError, '$nin needs an array or range'
      end
    end

    register(:nin, '$nin', NinMatcher)
  end
end
