# frozen_string_literal: true

module Mongory
  module Converters
    # ValueConverter transforms query values into a standardized form.
    # It handles arrays, hashes, regex, and basic types, and delegates
    # fallback logic to DataConverter.
    # Used by ConditionConverter to prepare values in nested queries.
    #
    # - Arrays are recursively converted
    # - Hashes are interpreted as nested conditions
    # - Regex becomes a Mongo-style `$regex` hash
    # - Strings and Integers are passed through
    # - Everything else falls back to DataConverter
    #
    # @example Convert a regex
    #   ValueConverter.instance.convert(/foo/) #=> { "$regex" => "foo" }
    #
    class ValueConverter < AbstractConverter
      alias_method :super_convert, :convert

      # Converts a value into its standardized form based on its type.
      # Handles arrays, hashes, regex, and basic types.
      #
      # @param target [Object] the value to convert
      # @return [Object] the converted value
      def convert(target)
        case target
        when String, Integer, Regexp
          target
        when Array
          target.map { |x| convert(x) }
        when Hash
          condition_converter.convert(target)
        else
          super_convert(target)
        end
      end

      def fallback(target, *)
        Mongory.data_converter.convert(target)
      end

      # Returns the condition converter instance.
      #
      # @return [ConditionConverter] the condition converter instance
      def condition_converter
        @condition_converter ||= Mongory.condition_converter
      end
    end
  end
end
