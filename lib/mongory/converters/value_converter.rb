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
      # Sets a fallback using DataConverter for unsupported types.
      #
      # @return [void]
      def initialize
        super
        @fallback = Proc.new do
          Mongory.data_converter.convert(self)
        end
      end

      def convert(target)
        case target
        when String, Integer, Regexp
          target
        when Array
          target.map { |x| convert(x) }
        when Hash
          condition_converter.convert(target)
        else
          super
        end
      end

      def condition_converter
        @condition_converter ||= Mongory.condition_converter
      end
    end
  end
end
