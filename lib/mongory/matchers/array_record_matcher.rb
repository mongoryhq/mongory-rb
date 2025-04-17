# frozen_string_literal: true

module Mongory
  module Matchers
    # ArrayRecordMatcher matches records where the record itself is an Array.
    #
    # This matcher checks whether any element of the record array satisfies the expected condition.
    # It is typically used when the record is a collection of values, and the query condition
    # is either a scalar value or a subcondition matcher.
    #
    # @example Match when any element equals the expected value
    #   matcher = ArrayRecordMatcher.build(42)
    #   matcher.match?([10, 42, 99])    #=> true
    #
    # @example Match using a nested matcher (e.g. condition is a hash)
    #   matcher = ArrayRecordMatcher.build({ '$gt' => 10 })
    #   matcher.match?([5, 20, 3])      #=> true
    #
    # This matcher is automatically invoked by LiteralMatcher when the record value is an array.
    #
    # @note This is distinct from `$in` or `$nin`, where the **condition** is an array.
    #       Here, the **record** is the array being matched against.
    #
    # @see Mongory::Matchers::InMatcher
    # @see Mongory::Matchers::LiteralMatcher
    class ArrayRecordMatcher < AbstractMultiMatcher
      # Builds an array of matchers to evaluate the given condition against an array record.
      #
      # This method returns multiple matchers that will be evaluated using `:any?` logic:
      # - An equality matcher for exact array match
      # - A hash condition matcher if the condition is a hash
      # - An `$elemMatch` matcher for element-wise comparison
      #
      # @return [Array<Mongory::Matchers::AbstractMatcher>] an array of matcher instances
      define_instance_cache_method(:matchers) do
        result = []
        result << EqMatcher.build(@condition)
        result << if @condition.is_a?(Hash)
                    HashConditionMatcher.build(parsed_condition)
                  else
                    ElemMatchMatcher.build('$eq' => @condition)
                  end
        result
      end

      # Combines results using `:any?` for multi-match logic.
      #
      # @return [Symbol]
      def operator
        :any?
      end

      private

      # Parses the original condition hash into a normalized structure suitable for HashConditionMatcher.
      #
      # This method classifies keys in the condition hash as:
      # - Numeric (integers or numeric strings): treated as index-based field matchers
      # - Operator keys (e.g., `$size`, `$type`): retained at the top level
      # - All other keys: grouped under a `$elemMatch` clause for element-wise comparison
      #
      # @return [Hash] a normalized condition hash, potentially containing `$elemMatch`
      def parsed_condition
        h_parsed = {}
        h_elem_match = {}
        @condition.each_pair do |key, value|
          case key
          when Integer, /^-?\d+$/
            h_parsed[key.to_i] = value
          when '$elemMatch'
            h_elem_match.merge!(value)
          when *Matchers::OPERATOR_TO_CLASS_MAPPING.keys
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
