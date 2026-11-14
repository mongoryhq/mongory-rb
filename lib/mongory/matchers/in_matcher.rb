# frozen_string_literal: true

module Mongory
  module Matchers
    # InMatcher implements the `$in` operator.
    #
    # It checks whether the record matches any value in the condition array.
    # If the record is an array, it succeeds if any item overlaps with the condition.
    # If the record is a single value (including `nil`), it matches if it is included in the condition.
    #
    # @example Match single value
    #   matcher = InMatcher.build([1, 2, 3])
    #   matcher.match?(2)        #=> true
    #   matcher.match?(5)        #=> false
    #
    # @example Match nil
    #   matcher = InMatcher.build([nil])
    #   matcher.match?(nil)      #=> true
    #
    # @example Match with array
    #   matcher = InMatcher.build([2, 4])
    #   matcher.match?([1, 2, 3])  #=> true
    #   matcher.match?([5, 6])     #=> false
    #
    # @see AbstractMatcher
    class InMatcher < AbstractMatcher
      def self.build(condition, context: Context.new)
        return super unless condition.is_a?(Range)

        end_op = condition.exclude_end? ? '$lt' : '$lte'
        head, tail = [condition.first, condition.last].sort
        AndMatcher.build([{ '$gte' => head }, { end_op => tail }], context: context)
      end

      # Creates a raw Proc that performs the in-matching operation.
      # The Proc checks if any element of the record is in the condition array.
      #
      # @return [Proc] a Proc that performs the in-matching operation
      def raw_proc
        condition = build_condition_set

        Proc.new do |record|
          if record.is_a?(Array)
            is_present?(condition & record)
          else
            condition.include?(record)
          end
        end
      end

      def priority
        1 + Math.log(@condition.size + 1, 1.5)
      end

      # Ensures the condition is an array or range.
      #
      # @raise [TypeError] if condition is not an array nor a range
      # @return [void]
      def check_validity!
        return if @condition.is_a?(Array)

        raise TypeError, '$in needs an array or range'
      end

      private

      def build_condition_set
        Set.new(@condition).tap do |set|
          @condition.each do |item|
            if item.is_a?(Integer)
              float_val = item.to_f
              set.add(float_val) if float_val == item
            elsif item.is_a?(Float) && item.finite?
              int_val = item.to_i
              set.add(int_val) if int_val == item
            end
          end
        end
      end
    end

    register(:in, '$in', InMatcher)
  end
end
