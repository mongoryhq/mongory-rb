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
      def convert(target)
        case target
        when String, Integer
          target
        when Symbol, Date
          target.to_s
        when Time, DateTime
          target.iso8601
        else
          super
        end
      end
    end
  end
end
