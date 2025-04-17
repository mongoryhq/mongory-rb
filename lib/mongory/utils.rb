# frozen_string_literal: true

require 'date'
require_relative 'utils/singleton_builder'
require_relative 'utils/debugger'

module Mongory
  # Utility helpers shared across Mongory internals.
  #
  # Includes blank checking, present checking,
  # and class-level instance method caching.
  module Utils
    # When included, also extends the including class with ClassMethods.
    # And record which class include this module.
    #
    # @param base [Class, Module]
    def self.included(base)
      base.extend(ClassMethods)
      super
      included_classes << base
    end

    # Where to record classes that include Utils.
    #
    # @return [Array]
    def self.included_classes
      @included_classes ||= []
    end

    # Checks if an object is "present".
    # Inverse of {#is_blank?}.
    #
    # @param obj [Object]
    # @return [Boolean]
    def is_present?(obj)
      !is_blank?(obj)
    end

    # Determines whether an object is considered "blank".
    # Nil, false, empty string/array/hash are blank.
    #
    # @param obj [Object]
    # @return [Boolean]
    def is_blank?(obj)
      case obj
      when false, nil
        true
      when Hash, Array, String
        obj.empty?
      else
        false
      end
    end

    # Class-level methods injected via Utils.
    module ClassMethods
      # Defines a lazily-evaluated, memoized instance method.
      #
      # @param name [Symbol] the method name
      # @yield block to compute the value
      # @return [void]
      #
      # @example
      #   define_instance_cache_method(:expensive_thing) { compute_something }
      def define_instance_cache_method(name, &block)
        instance_key = :"@#{name}"
        define_method(name) do
          return instance_variable_get(instance_key) if instance_variable_defined?(instance_key)

          instance_variable_set(instance_key, instance_exec(&block))
        end
      end
    end
  end
end
