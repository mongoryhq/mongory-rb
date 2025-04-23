# frozen_string_literal: true

module Mongory
  module Matchers
    # FieldMatcher handles field-level matching by extracting and comparing field values.
    #
    # This matcher is responsible for:
    # 1. Extracting field values from records using dot notation
    # 2. Converting extracted values if needed
    # 3. Delegating the actual comparison to a submatcher
    #
    # It supports:
    # - Hash records with string/symbol keys
    # - Array records with numeric indices
    # - Objects that respond to `[]`
    #
    # @example Basic field matching
    #   matcher = FieldMatcher.build('age', 30)
    #   matcher.match?({ 'age' => 30 })  #=> true
    #   matcher.match?({ age: 30 })      #=> true
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

      # Initializes a new field matcher.
      #
      # @param field [String, Symbol] the field to match against
      # @param condition [Object] the condition to match with
      # @param context [Context] the query context
      def initialize(field, condition, context: Context.new)
        @field = field
        super(condition, context: context)
      end

      # Creates a raw Proc that performs the field matching operation.
      # The Proc extracts the field value and delegates to the submatcher.
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

      # Creates a raw Proc that performs the field-based matching operation.
      # The Proc extracts the field value and delegates matching to the superclass.
      #
      # @return [Proc] A proc that performs field-based matching with context awareness
      # @note The proc handles field extraction and delegates matching to the superclass
      def raw_proc
        super_proc = super
        field = @field
        need_convert = @context.need_convert
        data_converter = Mongory.data_converter

        Proc.new do |record|
          sub_record =
            case record
            when Hash
              record.fetch(field) do
                record.fetch(field.to_sym, KEY_NOT_FOUND)
              end
            when Array
              record.fetch(field, KEY_NOT_FOUND)
            when KEY_NOT_FOUND, *CLASSES_NOT_ALLOW_TO_DIG
              next false
            else
              next false unless record.respond_to?(:[])

              record[field]
            end

          sub_record = data_converter.convert(sub_record) if need_convert
          super_proc.call(sub_record)
        end
      end

      # Returns a unique key for this matcher, including the field name.
      # Used for deduplication in multi-matchers.
      #
      # @return [String] a unique key for this matcher
      # @see AbstractMultiMatcher#matchers
      def uniq_key
        super + "field:#{@field}"
      end

      private

      # Returns a single-line summary of the field matcher including the field and condition.
      #
      # @return [String] a formatted title for tree display
      def tree_title
        "Field: #{@field.inspect} to match: #{@condition.inspect}"
      end

      # Custom display logic for debugging, including colored field highlighting.
      #
      # @param record [Object] the input record
      # @param result [Boolean] match result
      # @return [String] formatted debug string with highlighted field
      def debug_display(record, result)
        "#{self.class.name.split('::').last} #{colored_result(result)}, " \
          "condition: #{@condition.inspect}, " \
          "\e[30;47mfield: #{@field.inspect}\e[0m, " \
          "record: #{record.inspect.gsub(@field.inspect, "\e[30;47m#{@field.inspect}\e[0m")}"
      end
    end
  end
end
