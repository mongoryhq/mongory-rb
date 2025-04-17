# frozen_string_literal: true

module Mongory
  module Converters
    # DataConverter handles automatic transformation of raw query values.
    # This class inherits from AbstractConverter and provides predefined conversions for
    # common primitive types like Symbol, Date, Time, etc.
    # - Symbols and Dates are converted to string
    # - Time and DateTime objects are ISO8601-encoded
    # - Strings and Integers are passed through as-is
    #
    # @example Convert a symbol
    #   DataConverter.instance.convert(:status) #=> "status"
    #
    class DataConverter < AbstractConverter
      def default_registrations
        register(Symbol, :to_s)
        register(Date, :to_s)
        register(Time, :iso8601)
        register(DateTime, :iso8601)
        register(String, :itself)
        register(Integer, :itself)
      end
    end
  end
end
