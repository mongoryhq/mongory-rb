# frozen_string_literal: true

module Mongory
  module Utils
    # A singleton placeholder object used to represent special sentinel values.
    #
    # Used in situations where `nil` is a valid value and cannot be used as a marker.
    # Typically used for internal constants like `NOTHING` or `KEY_NOT_FOUND`.
    #
    # @example
    #   NOTHING = SingletonBuilder.new('NOTHING')
    #   value == NOTHING  # => true if placeholder
    class SingletonBuilder
      # @param label [String] a human-readable label for the marker
      def initialize(label, &block)
        @label = label
        instance_eval(&block) if block_given?
      end

      # @return [String] formatted label
      def inspect
        "#<#{@label}>"
      end

      # @return [String] formatted label
      def to_s
        "#<#{@label}>"
      end
    end
  end
end
