# frozen_string_literal: true

begin
  require 'mongory_ext'
rescue LoadError => e
  warn "Warning: Failed to load mongory_ext C extension: #{e.message}"
  warn "Falling back to pure Ruby implementation"

  # Fallback pure Ruby implementation
  module Mongory
    class CoreError < StandardError; end
    class CoreTypeError < CoreError; end

    # Minimal fallback implementation
    module Core
      def self.init
        # No-op for pure Ruby
      end

      def self.cleanup
        # No-op for pure Ruby
      end
    end

    class MemoryPool
      def initialize
        @objects = []
      end

      def self.new
        super
      end
    end

    class Matcher
      def initialize(pool, condition)
        @pool = pool
        @condition = condition
      end

      def self.new(pool, condition)
        super(pool, condition)
      end

      def match(data)
        # Fallback to pure Ruby matching
        # This would need to implement the actual matching logic
        false
      end
    end

    CORE_VERSION = "1.0.0-fallback".freeze
  end
end

module Mongory
  # High-level Ruby interface for the C extension
  module CoreInterface
    # Initialize the mongory core library
    def self.init
      Core.init if defined?(Core)
    end

    # Cleanup mongory core resources
    def self.cleanup
      Core.cleanup if defined?(Core)
    end

    # Create a new memory pool
    def self.create_memory_pool
      MemoryPool.new if defined?(MemoryPool)
    end

    # Create a matcher with the given condition
    def self.create_matcher(pool, condition)
      Matcher.new(pool, condition) if defined?(Matcher)
    end

    # Check if C extension is available
    def self.c_extension_available?
      defined?(::Mongory::Core) && ::Mongory::Core.respond_to?(:init)
    end

    # Get the core version
    def self.version
      defined?(CORE_VERSION) ? CORE_VERSION : "unknown"
    end
  end
end
