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
        when Symbol
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

      # Converts a dotted string key into nested hash form.
      # Splits the key on dots and builds a nested structure.
      # Handles escaped dots in the key.
      #
      # @param key [String] the dotted key string, e.g. "a.b.c"
      # @param value [Object] the value to assign at the deepest level
      # @return [Hash] nested hash structure
      def convert_string_key(key, value)
        ret = {}
        *sub_keys, last_key = key.split(/(?<!\\)\./)
        last_hash = sub_keys.reduce(ret) do |res, sub_key|
          next_res = res[normalize_key(sub_key)] = {}
          next_res
        end
        last_hash[normalize_key(last_key)] = value
        ret
      end

      # Normalizes a key by unescaping escaped dots.
      # This allows for literal dots in field names.
      #
      # @param key [String] the key to normalize
      # @return [String] the normalized key
      def normalize_key(key)
        key.gsub(/\\\./, '.')
      end
    end
  end
end
