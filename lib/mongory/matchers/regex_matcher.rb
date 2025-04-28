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
    # @example Basic regex matching
    #   matcher = RegexMatcher.build(/^foo/)
    #   matcher.match?('foobar')   #=> true
    #   matcher.match?('barfoo')   #=> false
    #
    # @example Case-insensitive matching
    #   matcher = RegexMatcher.build(/admin/i)
    #   matcher.match?("ADMIN")    #=> true
    #
    # @example String pattern
    #   matcher = RegexMatcher.build("^foo")
    #   matcher.match?("foobar")   #=> true
    #
    # @example Non-string input
    #   matcher = RegexMatcher.build(/\d+/)
    #   matcher.match?(123)        #=> false (not a string)
    #
    # @see AbstractMatcher
    class RegexMatcher < AbstractMatcher
      # Initializes the matcher with a regex pattern.
      # Converts string patterns to Regexp objects.
      #
      # @param condition [String, Regexp] the regex pattern to match against
      # @param context [Context] the query context
      # @raise [TypeError] if condition is not a string or Regexp
      def initialize(condition, context: Context.new)
        super
        @condition = Regexp.new(condition) if condition.is_a?(String)
      end

      # Creates a raw Proc that performs the regex matching operation.
      # The Proc checks if the record is a string that matches the pattern.
      # Returns false for non-string inputs or if the match fails.
      #
      # @return [Proc] a Proc that performs regex matching
      def raw_proc
        condition = @condition

        Proc.new do |record|
          next false unless record.is_a?(String)

          record.match?(condition)
        rescue StandardError
          false
        end
      end

      def priority
        @condition.source.start_with?('^') ? 8 : 20
      end

      # Ensures the condition is a valid regex pattern (Regexp or String).
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
