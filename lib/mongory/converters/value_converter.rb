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

      def default_registrations
        v_convert = method(:convert)
        register(Array) do
          map { |x| v_convert.call(x) }
        end

        # - Hashes are interpreted as nested condition trees
        #   using ConditionConverter
        register(Hash) do
          Mongory.condition_converter.convert(self)
        end

        register(String, :itself)
        register(Integer, :itself)
      end
    end
  end
end
