# frozen_string_literal: true

module Mongory
  module Matchers
    # Matcher for the `$size` operator.
    #
    # This matcher expects the input to be an array, and delegates the comparison
    # to a literal matcher using the array's size as the value.
    #
    # For example, the condition `{ tags: { '$size' => 3 } }` will match any
    # document where `tags` is an array of length 3.
    #
    # ### Supported compound usages:
    #
    # ```ruby
    # Mongory.where(tags: { '$size' => 3 })                       # exactly 3 elements
    # Mongory.where(tags: { '$size' => { '$gt' => 1 } })          # more than 1
    # Mongory.where(comments: { '$size' => { '$gt' => 1, '$lte' => 5 } })     # more than 1, up to 5 elements
    # Mongory.where(tags: { '$size' => { '$in' => [1, 2, 3] } })  # 1, 2, or 3 elements
    # ```
    #
    # @see LiteralMatcher
    #
    # @note Ruby's Symbol class already defines a `#size` method,
    #       that will return the size of the symbol object.
    #       So, this is the only operator that cannot be used with
    #       the symbol snippet syntax (e.g. `:tags.size`).
    #       
    #       Use string key syntax instead: `:"tags.$size" => ...`
    class SizeMatcher < LiteralMatcher
      # Creates a raw Proc that performs the size matching operation.
      #
      # The returned Proc checks if the input is an Array. If so, it calculates
      # the array's size and passes it to the wrapped literal matcher Proc.
      #
      # @return [Proc] A proc that performs size-based matching
      def raw_proc
        super_proc = super

        Proc.new do |record|
          next false unless record.is_a?(Array)

          super_proc.call(record.size)
        end
      end
    end

    register(:size, '$size', SizeMatcher)
  end
end
