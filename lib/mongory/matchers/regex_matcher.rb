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
    class RegexMatcher < AbstractOperatorMatcher
      # Uses `:match?` as the operator to invoke on the record string.
      #
      # @return [Symbol] the match? method symbol
      def operator
        :match?
      end

      # Ensures the record is a string before applying regex.
      # If not, coerces to empty string to ensure match fails safely.
      #
      # @param record [Object] the raw input
      # @return [String] a safe string to match against
      def preprocess(record)
        return '' unless record.is_a?(String)

        record
      end

      # Ensures the condition is a Regexp (strings are converted during initialization).
      #
      # @raise [TypeError] if condition is not a string
      # @return [void]
      def check_validity!
        return if @condition.is_a?(Regexp)
        return if @condition.is_a?(String)

        raise TypeError, '$regex needs a Regexp or string'
      end
    end
  end
end
