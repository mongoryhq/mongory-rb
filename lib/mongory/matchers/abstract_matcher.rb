# frozen_string_literal: true

module Mongory
  module Matchers
    # AbstractMatcher is the base class for all matchers in Mongory.
    #
    # It defines a common interface (`#match?`) and provides shared behavior
    # such as condition storage, optional conversion handling, and debugging output.
    #
    # Each matcher is responsible for evaluating a specific type of condition against
    # a record value. The base class provides infrastructure for:
    # - Condition validation
    # - Value conversion
    # - Debug output
    # - Proc caching
    #
    # @abstract Subclasses must implement {#match} to define their matching logic
    #
    # @example Basic matcher implementation
    #   class MyMatcher < AbstractMatcher
    #     def match(record)
    #       record == @condition
    #     end
    #   end
    #
    # @example Using a matcher
    #   matcher = MyMatcher.build(42)
    #   matcher.match?(42)  #=> true
    #   matcher.match?(43)  #=> false
    #
    # @see Mongory::Matchers for the full list of available matchers
    class AbstractMatcher
      include Utils

      singleton_class.alias_method :build, :new

      # Sentinel value used to represent missing keys when traversing nested hashes.
      # This is used instead of nil to distinguish between missing keys and nil values.
      #
      # @api private
      KEY_NOT_FOUND = SingletonBuilder.new('KEY_NOT_FOUND')

      # Defines a lazily-evaluated matcher accessor with instance-level caching.
      # This is used to create cached accessors for submatcher instances.
      #
      # @param name [Symbol] the name of the matcher (e.g., :collection)
      # @yield the block that constructs the matcher instance
      # @return [void]
      # @example
      #   define_matcher(:array_matcher) do
      #     ArrayMatcher.build(@condition)
      #   end
      def self.define_matcher(name, &block)
        define_instance_cache_method(:"#{name}_matcher", &block)
      end

      # @return [Object] the raw condition this matcher was initialized with
      attr_reader :condition

      # @return [Context] the query context containing configuration and current record
      attr_reader :context

      # Returns a unique key representing this matcher instance.
      # Used for deduplication in multi-matchers.
      #
      # @return [String] a unique key for this matcher instance
      # @see AbstractMultiMatcher#matchers
      def uniq_key
        "#{self.class}:condition:#{@condition.class}:#{@condition}"
      end

      # Initializes the matcher with a raw condition.
      #
      # @param condition [Object] the condition to match against
      # @param context [Context] the query context containing configuration
      def initialize(condition, context: Context.new)
        @condition = condition
        @context = context

        check_validity!
      end

      # Matches the given record against the condition.
      # This method handles error cases and uses the cached proc for performance.
      #
      # @param record [Object] the input record
      # @return [Boolean] whether the record matches the condition
      def match?(record)
        to_proc.call(record)
      rescue StandardError
        false
      end

      # Converts the matcher into a Proc that can be used for matching.
      # The Proc is cached for better performance.
      #
      # @return [Proc] a Proc that can be used to match records
      def cached_proc
        @cached_proc ||= raw_proc
      end

      alias_method :to_proc, :cached_proc

      # Creates a debug-enabled version of the matcher proc.
      # This version includes tracing and error handling.
      #
      # @return [Proc] a debug-enabled version of the matcher proc
      def debug_proc
        return @debug_proc if defined?(@debug_proc)

        raw_proc = raw_proc()
        @debug_proc = Proc.new do |record|
          result = nil

          Debugger.instance.with_indent do
            result = begin
              raw_proc.call(record)
            rescue StandardError => e
              e
            end

            debug_display(record, result)
          end

          result.is_a?(Exception) ? false : result
        end
      end

      # Creates a raw Proc from the match method.
      # This is used internally by to_proc and can be overridden by subclasses
      # to provide custom matching behavior.
      #
      # @return [Proc] the raw Proc implementation of the match method
      def raw_proc
        method(:match).to_proc
      end

      # Performs the actual match logic.
      # Subclasses must override this method.
      #
      # @abstract
      # @param record [Object] the input record to test
      # @return [Boolean] whether the record matches the condition
      def match(record); end

      # Validates the condition (no-op by default).
      # Override in subclasses to raise error if invalid.
      #
      # @abstract
      # @raise [TypeError] if the condition is invalid
      # @return [void]
      def check_validity!; end

      # Recursively prints the matcher structure into a formatted tree.
      # Supports indentation and branching layout using prefix symbols.
      #
      # @param prefix [String] tree prefix (indentation + lines)
      # @param is_last [Boolean] whether this node is the last among siblings
      # @return [void]
      def render_tree(prefix = '', is_last: true)
        puts "#{prefix}#{is_last ? '└─ ' : '├─ '}#{tree_title}\n"
      end

      private

      # Returns a single-line string representing this matcher in the tree output.
      # Format: `<MatcherType>: <condition.inspect>`
      #
      # @return [String] a formatted title for tree display
      def tree_title
        matcher_name = self.class.name.split('::').last.sub('Matcher', '')
        "#{matcher_name}: #{@condition.inspect}"
      end

      # Normalizes the record before matching.
      #
      # If the record is the KEY_NOT_FOUND sentinel (representing a missing field),
      # it is converted to `nil` so matchers can interpret it consistently.
      # Other values are returned as-is.
      #
      # @param record [Object] the record value to normalize
      # @return [Object, nil] the normalized record
      # @see Mongory::KEY_NOT_FOUND
      def normalize(record)
        record == KEY_NOT_FOUND ? nil : record
      end

      # Formats a debug string for match output.
      # Uses ANSI escape codes to highlight matched vs. mismatched records.
      #
      # @param record [Object] the record being tested
      # @param result [Boolean, Exception] whether the match succeeded or an error occurred
      # @return [String] the formatted output string
      def debug_display(record, result)
        "#{self.class.name.split('::').last} #{colored_result(result)}, " \
          "condition: #{@condition.inspect}, " \
          "record: #{record.inspect}"
      end

      # Formats the match result with ANSI color codes for terminal output.
      #
      # @param result [Boolean, Exception] the match result or error
      # @return [String] the colored result string
      def colored_result(result)
        if result.is_a?(Exception)
          "\e[45;97m#{result}\e[0m"
        elsif result
          "\e[30;42mMatched\e[0m"
        else
          "\e[30;41mDismatch\e[0m"
        end
      end
    end
  end
end
