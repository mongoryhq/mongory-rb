# frozen_string_literal: true

module Mongory
  module Matchers
    # AbstractMatcher is the base class for custom Ruby matchers in Mongory.
    #
    # Built-in operators are implemented natively in `mongory-core`. Subclass
    # `AbstractMatcher` and register it with `Mongory::Matchers.register` to extend
    # Mongory with custom operators evaluated via the `mongory-core` custom matcher bridge.
    #
    # @abstract Subclasses must implement {#match} to define their matching logic
    #
    # @example Custom matcher implementation
    #   class DivisibleByMatcher < Mongory::Matchers::AbstractMatcher
    #     def match(record)
    #       record.is_a?(Numeric) && (record % @condition).zero?
    #     end
    #
    #     def check_validity!
    #       raise Mongory::TypeError, '$divisibleBy needs a non-zero Integer' unless
    #         @condition.is_a?(Integer) && @condition != 0
    #     end
    #   end
    #
    #   Mongory::Matchers.register(:divisible_by, '$divisibleBy', DivisibleByMatcher)
    class AbstractMatcher
      include Utils

      singleton_class.alias_method :build, :new

      # Sentinel value used to represent missing keys.
      #
      # @api private
      KEY_NOT_FOUND = SingletonBuilder.new('KEY_NOT_FOUND').freeze

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

      # @return [Context] the query context containing configuration and current record
      attr_reader :context

      # Returns a unique key representing this matcher instance.
      #
      # @return [String] a unique key for this matcher instance
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
      #
      # @param record [Object] the input record
      # @return [Boolean] whether the record matches the condition
      def match?(record)
        to_proc.call(record)
      rescue StandardError
        false
      end

      # Converts the matcher into a Proc that can be used for matching.
      #
      # @return [Proc] a Proc that can be used to match records
      def cached_proc
        @cached_proc ||= raw_proc
      end

      alias_method :to_proc, :cached_proc

      # Creates a raw Proc from the match method.
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
      # @raise [Mongory::TypeError] if the condition is invalid
      # @return [void]
      def check_validity!; end

      # Returns the short class name of this matcher.
      #
      # @return [String]
      def matcher_name
        self.class.name.split('::').last.sub(/Matcher\z/, '')
      end

      def priority
        20
      end

      private

      # Normalizes the record before matching.
      #
      # @param record [Object] the record value to normalize
      # @return [Object, nil] the normalized record
      def normalize(record)
        record == KEY_NOT_FOUND ? nil : record
      end
    end
  end
end
