# frozen_string_literal: true

module Mongory
  module Converters
    # KeyConverter handles transformation of field keys in query conditions.
    # It normalizes symbol keys into string paths, splits dotted keys,
    # and delegates to the appropriate converter logic.
    #
    # This class inherits from AbstractConverter and provides specialized
    # handling for different key types:
    # - String keys with dots are split into nested paths
    # - Symbol keys are converted to strings
    # - QueryOperator instances are handled via their DSL hooks
    # - Other types fall back to the parent converter
    #
    # Used by ConditionConverter to build query structures from flat input.
    #
    # - `"a.b.c" => v` becomes `{ "a" => { "b" => { "c" => v } } }`
    # - Symbols are stringified and delegated to String logic
    # - QueryOperator dispatches to internal DSL hook
    #
    # @example Convert a dotted string key
    #   KeyConverter.instance.convert("user.name", "John")
    #   # => { "user" => { "name" => "John" } }
    #
    # @example Convert a symbol key
    #   KeyConverter.instance.convert(:status, "active")
    #   # => { "status" => "active" }
    #
    # @see AbstractConverter
    class KeyConverter < AbstractConverter
      alias_method :super_convert, :convert

      # Converts a key into its normalized form based on its type.
      # Handles strings, symbols, and QueryOperator instances.
      # Falls back to parent converter for other types.
      #
      # @param target [Object] the key to convert
      # @param other [Object] the value associated with the key
      # @return [Hash] the converted key-value pair
      def convert(target, other)
        case target
        when String
          convert_string_key(target, other)
        when Symbol, Integer
          convert_string_key(target.to_s, other)
        when QueryOperator
          # Handle special case for QueryOperator
          convert_string_key(*target.__expr_part__(other).first)
        else
          super_convert(target, other)
        end
      end

      def fallback(target, other)
        { target => other }
      end

      # Preserves the string key verbatim; dotted path expansion and escaped-dot
      # unescaping are handled natively by `mongory-core`.
      #
      # @param key [String] the field key string
      # @param value [Object] the condition value
      # @return [Hash] single-entry hash `{ key => value }`
      def convert_string_key(key, value)
        { key => value }
      end
    end
  end
end
