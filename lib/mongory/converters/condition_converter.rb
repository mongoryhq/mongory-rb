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
      #
      # @param condition [Hash]
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
      #
      # @return [Proc]
      def deep_merge_block
        @deep_merge_block ||= Proc.new do |_, a, b|
          if a.is_a?(Hash) && b.is_a?(Hash)
            a.merge(b, &deep_merge_block)
          else
            b
          end
        end
      end

      # Returns the key converter used to transform condition keys.
      #
      # @return [AbstractConverter]
      def key_converter
        KeyConverter.instance
      end

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

      undef_method :register, :exec_convert
    end
  end
end
