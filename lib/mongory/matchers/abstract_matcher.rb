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
      singleton_class.alias_method :build, :new

      # @return [Object] the raw condition this matcher was initialized with
      attr_reader :condition

      # @return [Utils::Context] the query context containing configuration and current record
      attr_reader :context

      # Initializes the matcher with a raw condition.
      #
      # @param condition [Object] the condition to match against
      # @param context [Utils::Context] the query context containing configuration
      def initialize(condition, context: Utils::Context.new)
        @condition = condition
        @context = context

        check_validity!
      end

      # Matches the given record against the condition.
      #
      # @param record [Object] the input record
      # @return [Boolean] whether the record matches the condition
      def match?(record)
        match(record)
      rescue StandardError
        false
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
    end
  end
end
