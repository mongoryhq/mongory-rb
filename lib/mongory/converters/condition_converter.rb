# frozen_string_literal: true

module Mongory
  module Converters
    # ConditionConverter transforms a flat condition hash into nested hash form.
    # This is used internally by ValueConverter to normalize condition structures
    # like { "foo.bar" => 1, "foo.baz" => 2 } into nested Mongo-style conditions.
    # Used by QueryMatcher to normalize condition input for internal matching.
    #
    # Combines key transformation (via KeyConverter) and
    # value normalization (via ValueConverter), and merges overlapping keys.
    #
    # @example Convert condition hash
    #   ConditionConverter.instance.convert({ "a.b" => 1, "a.c" => 2 })
    #   # => { "a" => { "b" => 1, "c" => 2 } }
    #
    class ConditionConverter < AbstractConverter
      # Converts a flat condition hash into a nested structure.
      # Applies both key and value conversion, and merges overlapping keys.
      #
      # @param condition [Hash] the flat condition hash to convert
      # @return [Hash] the transformed nested condition
      def convert(condition)
        result = {}
        condition.each_pair do |k, v|
          converted_value = value_converter.convert(v)
          converted_pair = key_converter.convert(k, converted_value)
          result.merge!(converted_pair, &deep_merge_block)
        end
        result
      end

      # Provides a block that merges values for overlapping keys in a deep way.
      # When both values are hashes, recursively merges them.
      # Otherwise, uses the second value.
      #
      # @return [Proc] a block for deep merging hash values
      def deep_merge_block
        @deep_merge_block ||= Proc.new do |_, a, b|
          if a.is_a?(Hash) && b.is_a?(Hash)
            a.merge(b, &deep_merge_block)
          else
            b
          end
        end
      end

      # @note Singleton instance, not configurable after initialization
      # Returns the key converter used to transform condition keys.
      #
      # @return [AbstractConverter] the key converter instance
      def key_converter
        KeyConverter.instance
      end

      # @note Singleton instance, not configurable after initialization
      # Returns the value converter used to transform condition values.
      #
      # @return [AbstractConverter]
      def value_converter
        ValueConverter.instance
      end

      # Freezes internal converters to prevent further modification.
      #
      # @return [void]
      def freeze
        deep_merge_block
        super
        key_converter.freeze
        value_converter.freeze
      end

      undef_method :register
    end
  end
end
