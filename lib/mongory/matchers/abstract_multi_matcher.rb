# frozen_string_literal: true

module Mongory
  module Matchers
    # AbstractMultiMatcher is an abstract base class for matchers that operate
    # on multiple subconditions. It provides a generic match loop that applies
    # a logical operator (e.g., `all?`, `any?`) over a list of sub-matchers.
    #
    # Subclasses must define two methods:
    #   - `#build_sub_matcher`: how to construct a matcher from each condition
    #   - `#operator`: which enumerator method to use (e.g., :all?, :any?)
    #
    # Sub-matchers are cached using `define_instance_cache_method` to prevent
    # repeated construction.
    #
    # @abstract
    # @see AbstractMatcher
    class AbstractMultiMatcher < AbstractMatcher
      # A Proc that always returns true, used as a default for empty AND conditions
      # @return [Proc] A proc that always returns true
      TRUE_PROC = Proc.new { |_| true }

      # A Proc that always returns false, used as a default for empty OR conditions
      # @return [Proc] A proc that always returns false
      FALSE_PROC = Proc.new { |_| false }

      # Enables auto-unwrap logic.
      # When used, `.build` may unwrap to first matcher if only one is present.
      #
      # @private
      # @return [void]
      def self.enable_unwrap!
        @enable_unwrap = true
        singleton_class.alias_method :build, :build_or_unwrap
      end

      private_class_method :enable_unwrap!

      # Builds a matcher and conditionally unwraps it.
      # If unwrapping is enabled and there is only one submatcher,
      # returns that submatcher instead of the multi-matcher wrapper.
      #
      # @param args [Array] arguments passed to the constructor
      # @param context [Context] the query context
      # @return [AbstractMatcher] the constructed matcher or its unwrapped submatcher
      def self.build_or_unwrap(*args, context: Context.new)
        matcher = new(*args, context: context)
        return matcher unless @enable_unwrap

        matcher = matcher.matchers.first if matcher.matchers.count == 1
        matcher
      end

      # Recursively checks all submatchers for validity.
      # Raises an error if any submatcher is invalid.
      #
      # @raise [Mongory::TypeError] if any submatcher is invalid
      # @return [void]
      def check_validity!
        matchers.each(&:check_validity!)
      end

      # Overrides base render_tree to recursively print all submatchers.
      # Each child matcher will be displayed under this multi-matcher node.
      #
      # @param prefix [String] current line prefix for tree alignment
      # @param is_last [Boolean] whether this node is the last sibling
      # @return [void]
      def render_tree(prefix = '', is_last: true)
        super

        new_prefix = "#{prefix}#{is_last ? '   ' : '│  '}"
        last_index = matchers.count - 1
        matchers.each_with_index do |matcher, index|
          matcher.render_tree(new_prefix, is_last: index == last_index)
        end
      end
    end
  end
end
