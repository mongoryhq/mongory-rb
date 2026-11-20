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

        def deep_merge(other)
          dup.deep_merge!(Hash.new(other))
        end

        def deep_merge!(other)
          _deep_merge!(self, Hash.new(other))
        end

        private

        def _deep_merge!(left, right)
          and_clauses = nil
          right.each_pair do |key, b|
            if !left.key?(key)
              left[key] = b
            elsif left[key].is_a?(::Hash) && b.is_a?(::Hash)
              left[key] = _deep_merge!(left[key].dup, b)
            else
              and_clauses ||= []
              and_clauses << Converted::Hash.new(key => left.delete(key))
              and_clauses << Converted::Hash.new(key => b)
            end
          end

          if and_clauses
            if left['$and'].is_a?(::Array)
              left['$and'] = Converted::Array.new(left['$and'] + and_clauses)
            elsif left.key?('$and')
              existing = Converted::Hash.new('$and' => left.delete('$and'))
              left['$and'] = Converted::Array.new([existing] + and_clauses)
            else
              left['$and'] = Converted::Array.new(and_clauses)
            end
          end

          left
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
