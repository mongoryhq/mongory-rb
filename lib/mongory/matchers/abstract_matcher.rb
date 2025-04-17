# frozen_string_literal: true

module Mongory
  module Matchers
    # AbstractMatcher is the base class for all matchers in Mongory.
    #
    # It defines a common interface (`#match?`) and provides shared behavior
    # such as condition storage, optional conversion handling, and debugging output.
    #
    # Subclasses are expected to implement `#match(record)` to define their matching logic.
    #
    # This class also supports caching of lazily-built matchers via `define_matcher`.
    #
    # @abstract
    class AbstractMatcher
      include Utils

      singleton_class.alias_method :build, :new
      # Sentinel value used to represent missing keys when traversing nested hashes.
      KEY_NOT_FOUND = SingletonBuilder.new('KEY_NOT_FOUND')

      # Defines a lazily-evaluated matcher accessor with instance-level caching.
      #
      # @param name [Symbol] the name of the matcher (e.g., :collection)
      # @yield the block that constructs the matcher instance
      # @return [void]
      def self.define_matcher(name, &block)
        define_instance_cache_method(:"#{name}_matcher", &block)
      end

      # @return [Object] the raw condition this matcher was initialized with
      attr_reader :condition

      # @return [String] a unique key representing this matcher instance, used for deduplication
      # @see AbstractMultiMatcher#matchers
      def uniq_key
        "#{self.class}:condition:#{@condition.class}:#{@condition}"
      end

      # Initializes the matcher with a raw condition.
      #
      # @param condition [Object] the condition to match against
      def initialize(condition)
        @condition = condition

        check_validity!
      end

      # Performs the actual match logic.
      # Subclasses must override this method.
      #
      # @param record [Object] the input record to test
      # @return [Boolean] whether the record matches the condition
      def match(record); end

      # Matches the given record against the condition.
      #
      # @param record [Object] the input record
      # @return [Boolean]
      def match?(record)
        match(record)
      rescue StandardError
        false
      end

      # Provides an alias to `#match?` for internal delegation.
      alias_method :regular_match, :match?

      # Evaluates the match with debugging output.
      # Increments indent level and prints visual result with colors.
      #
      # @param record [Object] the input record to test
      # @return [Boolean] whether the match succeeded
      def debug_match(record)
        result = nil

        Debugger.instance.with_indent do
          result = begin
            match(record)
          rescue StandardError => e
            e
          end

          debug_display(record, result)
        end

        result.is_a?(Exception) ? false : result
      end

      # Validates the condition (no-op by default).
      # Override in subclasses to raise error if invalid.
      #
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
      # @return [String]
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
      # @param result [Boolean] whether the match succeeded
      # @return [String] the formatted output string
      def debug_display(record, result)
        "#{self.class.name.split('::').last} #{colored_result(result)}, " \
          "condition: #{@condition.inspect}, " \
          "record: #{record.inspect}"
      end

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
