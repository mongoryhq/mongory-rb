# frozen_string_literal: true

module Mongory
  module Matchers
    # LiteralMatcher handles direct value comparison with special array handling.
    #
    # This matcher is used when a condition is a literal value (not an operator).
    # It handles both direct equality comparison and array-record scenarios.
    #
    # For array records:
    # - Uses ArrayRecordMatcher to check if any element matches
    # For non-array records:
    # - Uses appropriate matcher based on condition type (Hash, Regexp, nil, etc.)
    #
    # @example Basic equality matching
    #   matcher = LiteralMatcher.build(42)
    #   matcher.match?(42)       #=> true
    #   matcher.match?([42, 43]) #=> true (array contains 42)
    #
    # @example Regexp matching
    #   matcher = LiteralMatcher.build(/foo/)
    #   matcher.match?("foo")     #=> true
    #   matcher.match?(["foobar"]) #=> true
    #
    # @example Hash condition matching
    #   matcher = LiteralMatcher.build({ '$gt' => 10 })
    #   matcher.match?(15)        #=> true
    #   matcher.match?([5, 15])   #=> true
    #
    # @see AbstractMatcher
    # @see ArrayRecordMatcher
    class LiteralMatcher < AbstractMatcher
      # Creates a raw Proc that performs the literal matching operation.
      # The Proc handles both array and non-array records appropriately.
      #
      # @return [Proc] a Proc that performs the literal matching operation
      def raw_proc
        array_record_proc = nil
        dispatched_proc = dispatched_matcher.to_proc

        Proc.new do |record|
          if record.is_a?(Array)
            array_record_proc ||= array_record_matcher.to_proc
            array_record_proc.call(record)
          else
            dispatched_proc.call(record)
          end
        end
      end

      def priority
        1 + dispatched_matcher.priority
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
          HashConditionMatcher.build(@condition, context: @context)
        when Regexp
          RegexMatcher.build(@condition, context: @context)
        when nil
          OrMatcher.build([
            { '$exists' => false },
            { '$eq' => nil }
          ], context: @context)
        else
          EqMatcher.build(@condition, context: @context)
        end
      end

      # Lazily defines the collection matcher for array records.
      #
      # @see ArrayRecordMatcher
      # @return [ArrayRecordMatcher] the matcher used to match array-type records
      # @!method array_record_matcher
      define_matcher(:array_record) do
        ArrayRecordMatcher.build(@condition, context: @context)
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
      # @param prefix [String] the prefix string for tree rendering
      # @param is_last [Boolean] whether this is the last node in the tree
      # @return [void]
      def render_tree(prefix = '', is_last: true)
        super

        target_matcher = @array_record_matcher || dispatched_matcher
        target_matcher.render_tree("#{prefix}#{is_last ? '   ' : '│  '}", is_last: true)
      end
    end
  end
end
