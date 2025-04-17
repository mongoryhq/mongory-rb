# frozen_string_literal: true

module Mongory
  module Matchers
    # FieldMatcher is responsible for extracting a value from a record
    # using a field (or index) and then delegating the match to LiteralMatcher logic.
    #
    # It handles nested access in structures like Hashes or Arrays, and guards
    # against types that should not be dig into (e.g., String, Symbol, Proc).
    #
    # This matcher is typically used when the query refers to a specific field,
    # like `{ age: { :$gte => 18 } }` where `:age` is passed as the dig field.
    #
    # @example
    #   matcher = FieldMatcher.build(:age, { :$gte => 18 })
    #   matcher.match?({ age: 20 }) #=> true
    #
    # @see LiteralMatcher
    class FieldMatcher < LiteralMatcher
      # A list of classes that should never be used for value digging.
      # These typically respond to `#[]` but are semantically invalid for this context.
      CLASSES_NOT_ALLOW_TO_DIG = [
        ::String,
        ::Integer,
        ::Proc,
        ::Method,
        ::MatchData,
        ::Thread,
        ::Symbol
      ].freeze

      # Initializes the matcher with a target field and condition.
      #
      # @param field [Object] the field (or index) used to dig into the record
      # @param condition [Object] the condition to match against the extracted value
      def initialize(field, condition)
        @field = field
        super(condition)
      end

      # Performs field-based matching against the given record.
      #
      # This method first ensures the record is structurally eligible for field extraction—
      # it must be a Hash, Array, or respond to `[]`. If the structure does not allow for
      # field access (e.g., nil, primitive values, or unsupported types), the match returns false.
      #
      # The field value is then extracted using the following rules:
      # - If the record is a Hash, it attempts to fetch using the field key,
      #   falling back to symbolized key if needed.
      # - If the record is an Array, it fetches by index.
      # - If the record does not support `[]` or is disallowed for dig operations,
      #   the match returns false immediately.
      #
      # Once the value is extracted, it is passed through the data converter
      # and matched against the condition via the superclass.
      #
      # @param record [Object] the input data structure to be matched
      # @return [Boolean] true if the extracted field value matches the condition; false otherwise
      #
      # @example Matching a Hash with a nil field value
      #   matcher = Mongory::QueryMatcher.new(a: nil)
      #   matcher.match?({ a: nil }) # => true
      #
      # @example Record is nil (structure not diggable)
      #   matcher = Mongory::QueryMatcher.new(a: nil)
      #   matcher.match?(nil) # => false
      #
      # @example Matching against an Array by index
      #   matcher = Mongory::QueryMatcher.new(0 => /abc/)
      #   matcher.match?(['abcdef']) # => true
      #
      # @example Hash with symbol key, matcher uses string key
      #   matcher = Mongory::QueryMatcher.new('a' => 123)
      #   matcher.match?({ a: 123 }) # => true
      def match(record)
        sub_record =
          case record
          when Hash
            record.fetch(@field) do
              record.fetch(@field.to_sym, KEY_NOT_FOUND)
            end
          when Array
            record.fetch(@field, KEY_NOT_FOUND)
          when KEY_NOT_FOUND, *CLASSES_NOT_ALLOW_TO_DIG
            return false
          else
            return false unless record.respond_to?(:[])

            record[@field]
          end

        super(Mongory.data_converter.convert(sub_record))
      end

      # @return [String] a deduplication field used for matchers inside multi-match constructs
      # @see AbstractMultiMatcher#matchers
      def uniq_key
        super + "field:#{@field}"
      end

      private

      # Returns a single-line summary of the dig matcher including the field and condition.
      #
      # @return [String]
      def tree_title
        "Field: #{@field.inspect} to match: #{@condition.inspect}"
      end

      # Custom display logic for debugging, including colored field highlighting.
      #
      # @param record [Object] the input record
      # @param result [Boolean] match result
      # @return [String] formatted debug string
      def debug_display(record, result)
        "#{self.class.name.split('::').last} #{colored_result(result)}, " \
          "condition: #{@condition.inspect}, " \
          "\e[30;47mfield: #{@field.inspect}\e[0m, " \
          "record: #{record.inspect.gsub(@field.inspect, "\e[30;47m#{@field.inspect}\e[0m")}"
      end
    end
  end
end
