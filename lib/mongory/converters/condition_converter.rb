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
        return condition if condition.is_a?(Converted)

        result = Converted::Hash.new
        condition.each_pair do |k, v|
          converted_value = value_converter.convert(v)
          converted_pair = key_converter.convert(k, converted_value)
          result.deep_merge!(converted_pair)
        end

        result
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
        super
        key_converter.freeze
        value_converter.freeze
      end

      undef_method :register
    end
  end
end
