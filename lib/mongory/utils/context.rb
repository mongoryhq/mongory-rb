# frozen_string_literal: true

module Mongory
  module Utils
    # Context is a utility class that provides a stable but mutatable
    # shared context for the Mongory query builder. It holds the configuration
    # and the current record being matcher tree processed.
    #
    # @example
    #   context = Mongory::Utils::Context.new(config)
    #   context.current_record = record
    #   context.config = new_config
    #
    # @attr [Config] config The configuration object for the context.
    # @attr [Record] current_record The current record being processed.
    class Context
      attr_accessor :config, :current_record

      # Initializes a new Context instance with the given configuration.
      #
      # @param config [Config] The configuration object for the context.
      # @return [Context] A new Context instance.
      def initialize(config = {})
        @config = config
        @current_record = nil
      end
    end
  end
end
