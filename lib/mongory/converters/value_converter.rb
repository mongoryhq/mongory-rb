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
      # fallback for unrecognized types
      def initialize
        super
        d_convert = nil
        @fallback = Proc.new do
          d_convert ||= DataConverter.instance.method(:convert)
          d_convert.call(self)
        end
      end

      def default_registrations
        v_convert = method(:convert)
        register(Array) do
          map { |x| v_convert.call(x) }
        end

        c_convert = nil
        register(Hash) do
          c_convert ||= ConditionConverter.instance.method(:convert)
          c_convert.call(self)
        end

        register(String, :itself)
        register(Integer, :itself)
      end
    end
  end
end
