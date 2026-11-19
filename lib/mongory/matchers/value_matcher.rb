# frozen_string_literal: true

module Mongory
  module Matchers
    # ValueMatcher handles direct value comparison with special array handling.
    #
    # This matcher is used when a condition is a literal value (not an operator).
    # It handles both direct equality comparison and array-record scenarios.
    #
    # For array records:
    # - Uses ImplicitArrayMatcher to check if any element matches
    # For non-array records:
    # - Uses appropriate matcher based on condition type (Hash, Regexp, nil, etc.)
    #
    # @example Basic equality matching
    #   matcher = ValueMatcher.build(42)
    #   matcher.match?(42)       #=> true
    #   matcher.match?([42, 43]) #=> true (array contains 42)
    #
    # @example Regexp matching
    #   matcher = ValueMatcher.build(/foo/)
    #   matcher.match?("foo")     #=> true
    #   matcher.match?(["foobar"]) #=> true
    #
    # @example Hash condition matching
    #   matcher = ValueMatcher.build({ '$gt' => 10 })
    #   matcher.match?(15)        #=> true
    #   matcher.match?([5, 15])   #=> true
    #
    # @see AbstractMatcher
    # @see ImplicitArrayMatcher
    class ValueMatcher < AbstractMatcher
      def matcher_name
        'Value'
      end

      # Creates a raw Proc that performs the literal matching operation.
      # The Proc handles both array and non-array records appropriately.
      #
      # @return [Proc] a Proc that performs the literal matching operation
      def raw_proc
        array_record_proc = @implicit_array_matcher&.to_proc
        dispatched_proc = dispatched_matcher.to_proc

        Proc.new do |record|
          if record.is_a?(Array)
            unless array_record_proc
              built = !instance_variable_defined?(:@implicit_array_matcher)
              array_record_proc = implicit_array_matcher.to_proc
              notify_priority_changed if built
            end
            array_record_proc.call(record)
          else
            dispatched_proc.call(record)
          end
        end
      end

      def priority
        1 + (@implicit_array_matcher || dispatched_matcher).priority
      end

      # Selects and returns the appropriate matcher instance for a given literal condition.
      #
      # This method analyzes the type of the raw condition (e.g., Hash, Regexp, nil)
      # and returns a dedicated matcher instance accordingly:
      #
      # - Hash → dispatches to `ConditionMatcher`
      # - Regexp → dispatches to `RegexMatcher`
      # - nil → dispatches to an `OrMatcher` that emulates MongoDB's `{ field: nil }` behavior
      #
      # For all other literal types, this method returns `EqMatcher`, and fallback equality matching will be used.
      #
      # This matcher is cached after the first invocation using `define_instance_cache_method`
      # to avoid unnecessary re-instantiation.
      #
      # @see Mongory::Matchers::ConditionMatcher
      # @see Mongory::Matchers::RegexMatcher
      # @see Mongory::Matchers::OrMatcher
      # @see Mongory::Matchers::EqMatcher
      # @return [AbstractMatcher] the matcher used for non-array literal values
      # @!method dispatched_matcher
      define_matcher(:dispatched) do
        matcher = case @condition
                  when Hash
                    ConditionMatcher.build(@condition, context: @context)
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
        attach_child(matcher)
      end

      # Lazily defines the collection matcher for array records.
      #
      # @see ImplicitArrayMatcher
      # @return [ImplicitArrayMatcher] the matcher used to match array-type records
      # @!method implicit_array_matcher
      define_matcher(:implicit_array) do
        attach_child(ImplicitArrayMatcher.build(@condition, context: @context))
      end

      # Validates the nested condition matcher, if applicable.
      #
      # @return [void]
      def check_validity!
        dispatched_matcher.check_validity!
      end

      # Returns the active delegated submatcher for explain_tree and trace_tree traversal.
      #
      # @return [Array<AbstractMatcher>]
      def child_matchers
        [@implicit_array_matcher || dispatched_matcher]
      end
    end
  end
end
