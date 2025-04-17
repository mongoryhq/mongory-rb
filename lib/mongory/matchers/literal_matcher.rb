# frozen_string_literal: true

module Mongory
  module Matchers
    # LiteralMatcher is responsible for handling raw literal values in query conditions.
    #
    # This matcher dispatches logic based on the type of the literal value,
    # such as nil, Array, Regexp, Hash, etc., and delegates to the appropriate specialized matcher.
    #
    # It is used when the query condition is a direct literal and not an operator or nested query.
    #
    # @example Supported usages
    #   { name: "Alice" }         # String literal
    #   { age: 18 }               # Numeric literal
    #   { active: true }          # Boolean literal
    #   { tags: [1, 2, 3] }       # Array literal → ArrayRecordMatcher
    #   { email: /@gmail\\.com/i } # Regexp literal → RegexMatcher
    #   { info: nil }             # nil literal → nil_matcher (matches null or missing)
    #
    # @note This matcher is commonly dispatched from HashConditionMatcher or FieldMatcher
    #       when the condition is a simple literal value, not an operator hash.
    #
    # === Supported literal types:
    # - String
    # - Integer / Float
    # - Symbol
    # - TrueClass / FalseClass
    # - NilClass → delegates to nil_matcher
    # - Regexp → delegates to RegexMatcher
    # - Array → delegates to ArrayRecordMatcher
    # - Hash → delegates to HashConditionMatcher (if treated as sub-query)
    # - Other unrecognized values → fallback to equality match (==)
    #
    # === Excluded types (handled by other matchers):
    # - Operator hashes like `{ "$gt" => 5 }` → handled by OperatorMatcher
    # - Nested paths like `"a.b.c"` → handled by FieldMatcher
    # - Query combinators like `$or`, `$and`, `$not` → handled by corresponding matchers
    #
    # @see Mongory::Matchers::RegexMatcher
    # @see Mongory::Matchers::OrMatcher
    # @see Mongory::Matchers::ArrayRecordMatcher
    # @see Mongory::Matchers::HashConditionMatcher
    class LiteralMatcher < AbstractMatcher
      # Matches the given record against the condition.
      #
      # @param record [Object] the record to be matched
      # @return [Boolean] whether the record satisfies the condition
      def match(record)
        case record
        when Array
          array_record_matcher.match?(record)
        else
          dispatched_matcher.match?(record)
        end
      end

      # Selects and returns the appropriate matcher instance for a given literal condition.
      #
      # This method analyzes the type of the raw condition (e.g., Hash, Regexp, nil)
      # and returns a dedicated matcher instance accordingly:
      #
      # - Hash → dispatches to `HashConditionMatcher`
      # - Regexp → dispatches to `RegexMatcher`
      # - nil → dispatches to an `OrMatcher` that emulates MongoDB's `{ field: nil }` behavior
      #
      # For all other literal types, this method returns `EqMatcher`, and fallback equality matching will be used.
      #
      # This matcher is cached after the first invocation using `define_instance_cache_method`
      # to avoid unnecessary re-instantiation.
      #
      # @see Mongory::Matchers::HashConditionMatcher
      # @see Mongory::Matchers::RegexMatcher
      # @see Mongory::Matchers::OrMatcher
      # @see Mongory::Matchers::EqMatcher
      # @return [AbstractMatcher] the matcher used for non-array literal values
      # @!method dispatched_matcher
      define_matcher(:dispatched) do
        case @condition
        when Hash
          HashConditionMatcher.build(@condition)
        when Regexp
          RegexMatcher.build(@condition)
        when nil
          OrMatcher.build([
            { '$exists' => false },
            { '$eq' => nil }
          ])
        else
          EqMatcher.build(@condition)
        end
      end

      # Lazily defines the collection matcher for array records.
      #
      # @see ArrayRecordMatcher
      # @return [ArrayRecordMatcher] the matcher used to match array-type records
      # @!method array_record_matcher
      define_matcher(:array_record) do
        ArrayRecordMatcher.build(@condition)
      end

      # Validates the nested condition matcher, if applicable.
      #
      # @return [void]
      def check_validity!
        dispatched_matcher.check_validity!
      end

      # Outputs the matcher tree by selecting either collection or condition matcher.
      # Delegates `render_tree` to whichever submatcher was active.
      #
      # @param prefix [String]
      # @param is_last [Boolean]
      # @return [void]
      def render_tree(prefix = '', is_last: true)
        super

        target_matcher = @array_record_matcher || dispatched_matcher
        target_matcher.render_tree("#{prefix}#{is_last ? '   ' : '│  '}", is_last: true)
      end
    end
  end
end
