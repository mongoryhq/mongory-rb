# frozen_string_literal: true

module Mongory
  module Matchers
    # RegexMatcher implements the `$regex` operator and also handles raw Regexp values.
    #
    # This matcher checks whether a string record matches a regular expression.
    # It supports both:
    # - Explicit queries using `:field.regex => /pattern/i`
    # - Implicit literal Regexp values like `{ field: /pattern/i }`
    #
    # If a string is provided instead of a Regexp, it will be converted via `Regexp.new(...)`.
    # This ensures consistent behavior for queries like `:field.regex => "foo"` and `:field.regex => /foo/`.
    #
    # @example
    #   matcher = RegexMatcher.build('^foo')
    #   matcher.match?('foobar')   #=> true
    #   matcher.match?('barfoo')   #=> false
    #
    # @example Match with explicit regex
    #   RegexMatcher.build(/admin/i).match?("ADMIN") # => true
    #
    # @example Match via LiteralMatcher fallback
    #   LiteralMatcher.new(/admin/i).match("ADMIN") # => true
    #
    # @see LiteralMatcher
    # @see Mongory::Matchers::AbstractOperatorMatcher
    class RegexMatcher < AbstractMatcher
      # Initializes the matcher with a regex pattern.
      # Converts string patterns to Regexp objects.
      #
      # @param condition [String, Regexp] the regex pattern to match against
      def initialize(condition)
        super(condition)
        @condition = Regexp.new(condition) if condition.is_a?(String)
      end

      # Checks if the record matches the regex pattern.
      #
      # @param record [Object] the value to test
      # @return [Boolean] true if the record is a string that matches the pattern
      def match(record)
        return false unless record.is_a?(String)

        record.match?(@condition)
      end

      # Creates a raw Proc that performs the regex matching operation.
      # The Proc checks if the record is a string that matches the pattern.
      #
      # @return [Proc] a Proc that performs the regex matching operation
      def raw_proc
        condition = @condition

        Proc.new do |record|
          next false unless record.is_a?(String)

          record.match?(condition)
        end
      end

      # Ensures the condition is a Regexp (strings are converted during initialization).
      #
      # @raise [TypeError] if condition is not a string or Regexp
      # @return [void]
      def check_validity!
        return if @condition.is_a?(Regexp)
        return if @condition.is_a?(String)

        raise TypeError, '$regex needs a Regexp or string'
      end
    end

    register(:regex, '$regex', RegexMatcher)
  end
end
