# frozen_string_literal: true

module Mongory
  # This class is the C extension of Mongory::QueryMatcher.
  # It is used to match records using the C extension.
  # @example
  #   matcher = Mongory::CMatcher.new(condition)
  #   matcher.match?(record) #=> true
  #   # or
  #   collection.mongory.c.where(condition).to_a
  class CMatcher
    # @!method self.new(condition)
    #   @param condition [Object] the condition
    #   @return [Mongory::CMatcher] a new matcher
    #   @note This method is implemented in the C extension
    #
    #   @!method match?(record)
    #     @param record [Object] the record to match against
    #     @return [Boolean] true if the record matches the condition, false otherwise
    #     @note This method is implemented in the C extension
    #   @!method explain
    #     @return [void]
    #     @note This method will print metcher tree structure
    #     @note This method is implemented in the C extension
    #   @!method trace
    #     @return [Boolean] true if the record matches the condition, false otherwise
    #     @note This method will print matching process
    #     @note This method is implemented in the C extension
    #   @!method enable_trace
    #     @return [void]
    #     @note This method will enable trace
    #     @note This method is implemented in the C extension
    #   @!method disable_trace
    #     @return [void]
    #     @note This method will disable trace
    #     @note This method is implemented in the C extension
    #   @!method print_trace
    #     @return [void]
    #     @note This method will print trace result
    #     @note This method is implemented in the C extension
    #   @!method condition
    #     @return [Object] the condition
    #     @note This method is implemented in the C extension
    #   @!method context
    #     @return [Utils::Context] the context
    #     @note This method is implemented in the C extension
    #   @!method trace_result_colorful=
    #     @param colorful [Boolean] whether to enable colorful trace result
    #     @return [Boolean]
    #     @note This method is implemented in the C extension

    # @return [Proc] a Proc that performs the matching operation
    def to_proc
      Proc.new { |record| match?(record) }
    end
  end
end
