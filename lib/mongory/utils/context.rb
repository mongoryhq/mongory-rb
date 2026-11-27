# frozen_string_literal: true

module Mongory
  module Utils
    # Context is a utility class that provides a stable, mutable shared context
    # for the Mongory query builder and custom matchers. It holds user-defined
    # configuration and the current record being processed.
    #
    # @example
    #   context = Mongory::Utils::Context.new(tenant: current_tenant)
    #   context.current_record = record
    #
    # @attr [Hash] config The configuration hash for the context
    # @attr [Object] current_record The current record being processed
    class Context
      attr_accessor :config, :current_record

      # Initializes a new Context instance with the given configuration.
      #
      # @param config [Hash] The configuration hash for the context.
      # @return [Context] A new Context instance.
      def initialize(config = {})
        @config = config
        @current_record = nil
      end

      # Creates a duplicate of the context with its own configuration hash.
      #
      # @return [Context] A new context instance with duplicated configuration
      def dup
        new_context = super
        new_context.config = @config.dup
        new_context
      end
    end
  end
end
