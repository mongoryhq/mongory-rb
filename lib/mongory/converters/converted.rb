# frozen_string_literal: true

module Mongory
  module Converters
    # Converted is a module that provides conversion structures marked as
    # Converted. It is used to convert various types of data into a
    # standardized form for MongoDB queries. The module includes
    # classes for converting hashes and arrays into nested structures.
    # It is used internally by the ConditionConverter and ValueConverter
    # to handle the conversion of complex data types into a format
    # suitable for MongoDB queries.
    module Converted
      def instance_convert(other)
        return other if other.is_a?(Converted)

        case other
        when ::Hash
          Converted::Hash.new(other)
        when ::Array
          Converted::Array.new(other)
        else
          other
        end
      end

      # Converts a flat condition hash into a nested structure.
      # Applies value conversion to each element.
      # This is used for conditions that are hashes of values.
      # It is used internally by the ConditionConverter and ValueConverter
      # to handle the conversion of complex data types into a format
      # suitable for MongoDB queries.
      class Hash < ::Hash
        include Converted

        def initialize(other = {})
          super()
          other.each_pair do |k, v|
            self[k] = instance_convert(v)
          end
        end

        def deep_merge!(other)
          _deep_merge!(self, Hash.new(other))
        end

        private

        def _deep_merge!(left, right)
          and_clauses = []
          right.each_pair do |key, val|
            _merge_entry!(left, key, val, and_clauses)
          end
          _append_and_clauses!(left, and_clauses) unless and_clauses.empty?
          left
        end

        def _merge_entry!(left, key, val, and_clauses)
          if !left.key?(key)
            left[key] = val
          elsif left[key].is_a?(::Hash) && val.is_a?(::Hash)
            left[key] = _deep_merge!(left[key].dup, val)
          else
            and_clauses << Converted::Hash.new(key => left.delete(key))
            and_clauses << Converted::Hash.new(key => val)
          end
        end

        def _append_and_clauses!(left, and_clauses)
          existing = left['$and']
          merged = if existing.is_a?(::Array)
                     existing + and_clauses
                   elsif left.key?('$and')
                     [Converted::Hash.new('$and' => left.delete('$and')), *and_clauses]
                   else
                     and_clauses
                   end
          left['$and'] = Converted::Array.new(merged)
        end
      end

      # Converts a flat condition array into a nested structure.
      # Applies value conversion to each element.
      # This is used for conditions that are arrays of values.
      # It is used internally by the ConditionConverter and ValueConverter
      # to handle the conversion of complex data types into a format
      # suitable for MongoDB queries.
      class Array < ::Array
        include Converted

        def initialize(other)
          super()
          other.each do |v|
            self << instance_convert(v)
          end
        end
      end
    end
  end
end
