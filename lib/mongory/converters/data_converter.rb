# frozen_string_literal: true

module Mongory
  module Converters
    # DataConverter handles automatic transformation of raw query values.
    # This class inherits from AbstractConverter and provides predefined conversions for
    # common primitive types like Symbol, Date, Time, etc.
    # - Symbols and Date objects are converted to string
    # - Time and DateTime objects are ISO8601-encoded
    # - Strings and Integers are passed through as-is
    #
    # @example Convert a symbol
    #   DataConverter.instance.convert(:status) #=> "status"
    #
    class DataConverter < AbstractConverter
      alias_method :super_convert, :convert

      # Converts a value into its standardized form based on its type.
      # Handles common primitive types with predefined conversion rules.
      #
      # @param target [Object] the value to convert
      # @return [Object] the converted value
      def convert(target)
        case target
        when String, Integer, Hash, Array
          target
        when Symbol, Date
          target.to_s
        when Time, DateTime
          target.iso8601
        else
          super_convert(target)
        end
      end
    end
  end
end
