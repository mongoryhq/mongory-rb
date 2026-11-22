# frozen_string_literal: true

module Mongory
  # Core query matcher backed by the `mongory-core` C99 native extension.
  #
  # @example
  #   matcher = Mongory::Matcher.new(age: { :$gte => 18 })
  #   matcher.match?(age: 20) #=> true
  #   # or
  #   collection.mongory.where(age: { :$gte => 18 }).to_a
  class Matcher
    # @!method self.new(condition, context: Utils::Context.new)
    #   @param condition [Hash] the condition
    #   @param context [Utils::Context] optional query context
    #   @return [Mongory::Matcher] a new matcher
    #   @note This method is implemented in the C extension
    # @!method self.trace_result_colorful=(colorful)
    #   @param colorful [Boolean] whether to enable colorful trace result
    #   @return [void]
    #   @note This method is implemented in the C extension
    #
    # @!method match?(record)
    #   @param record [Object] the record to match against
    #   @return [Boolean] true if the record matches the condition, false otherwise
    #   @note This method is implemented in the C extension
    # @!method explain_tree
    #   @return [Hash] structured explain tree
    #   @note This method is implemented in the C extension
    # @!method explain
    #   @return [void]
    #   @note Prints the matcher tree structure to STDOUT
    #   @note This method is implemented in the C extension
    # @!method trace_tree(record)
    #   @param record [Object] the record to trace against
    #   @return [Hash] structured trace tree
    #   @note This method is implemented in the C extension
    # @!method trace(record)
    #   @param record [Object] the record to trace against
    #   @return [Boolean] true if the record matches the condition, false otherwise
    #   @note Prints the matching process to STDOUT
    #   @note This method is implemented in the C extension
    # @!method condition
    #   @return [Hash] the normalized condition
    #   @note This method is implemented in the C extension
    # @!method context
    #   @return [Utils::Context] the context
    #   @note This method is implemented in the C extension

    # @return [Proc] a Proc that performs the matching operation
    def to_proc
      Proc.new { |record| match?(record) }
    end
  end
end
