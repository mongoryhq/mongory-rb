# frozen_string_literal: true

module Mongory
  module Matchers
    # ArrayRecordMatcher handles matching against array-type records.
    #
    # This matcher is used when a field value is an array and needs to be matched
    # against a condition. It supports both exact array matching and element-wise
    # comparison through `$elemMatch`.
    #
    # For empty conditions, it returns false (using FALSE_PROC).
    #
    # @example Match exact array
    #   matcher = ArrayRecordMatcher.build([1, 2, 3])
    #   matcher.match?([1, 2, 3])  #=> true
    #   matcher.match?([1, 2])     #=> false
    #
    # @example Match with hash condition
    #   matcher = ArrayRecordMatcher.build({ '$gt' => 5 })
    #   matcher.match?([3, 6, 9])  #=> true (6 and 9 match)
    #   matcher.match?([1, 2, 3])  #=> false
    #
    # @example Empty conditions
    #   matcher = ArrayRecordMatcher.build([])
    #   matcher.match?(record) #=> false (uses FALSE_PROC)
    #
    # @see AbstractMultiMatcher
    class ArrayRecordMatcher < AbstractMultiMatcher
      enable_unwrap!

      # Creates a raw Proc that performs the array matching operation.
      # The Proc checks if any element in the array matches the condition.
      # For empty conditions, returns FALSE_PROC.
      #
      # @return [Proc] a Proc that performs the array matching operation
      def raw_proc
        combine_procs_with_or(*matchers.map(&:to_proc))
      end

      # Builds an array of matchers to evaluate the given condition against an array record.
      #
      # This method returns multiple matchers that will be evaluated using `:any?` logic:
      # - An equality matcher for exact array match
      # - A hash condition matcher if the condition is a hash
      # - An `$elemMatch` matcher for element-wise comparison
      #
      # @return [Array<AbstractMatcher>] An array of matcher instances
      define_instance_cache_method(:matchers) do
        result = []
        result << EqMatcher.build(@condition, context: @context) if @condition.is_a?(Array)
        result << case @condition
                  when Hash
                    HashConditionMatcher.build(parsed_condition, context: @context)
                  when Regexp
                    ElemMatchMatcher.build({ '$regex' => @condition }, context: @context)
                  else
                    ElemMatchMatcher.build({ '$eq' => @condition }, context: @context)
                  end
        result.sort_by(&:priority)
      end

      private

      # Parses the original condition hash into a normalized structure suitable for HashConditionMatcher.
      #
      # This method classifies keys in the condition hash as:
      # - Numeric (integers or numeric strings): treated as index-based field matchers
      # - Operator keys (e.g., `$size`, `$type`): retained at the top level
      # - All other keys: grouped under a `$elemMatch` clause for element-wise comparison
      #
      # @return [Hash] A normalized condition hash, potentially containing `$elemMatch`
      def parsed_condition
        h_parsed = {}
        h_elem_match = {}
        @condition.each_pair do |key, value|
          case key
          when Integer, /^-?\d+$/
            h_parsed[key.to_i] = value
          when '$elemMatch'
            h_elem_match.merge!(value)
          when *Matchers.operators
            h_parsed[key] = value
          else
            h_elem_match[key] = value
          end
        end

        h_parsed['$elemMatch'] = h_elem_match if is_present?(h_elem_match)
        h_parsed
      end
    end
  end
end
