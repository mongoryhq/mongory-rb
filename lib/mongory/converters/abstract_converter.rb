# frozen_string_literal: true

module Mongory
  module Converters
    # AbstractConverter provides a flexible DSL-style mechanism
    # for dynamically converting objects based on their class.
    #
    # It allows you to register conversion rules for specific classes,
    # with optional fallback behavior.
    #
    # @example Basic usage
    #   converter = AbstractConverter.instance
    #   converter.register(String) { |v| v.upcase }
    #   converter.convert("hello") #=> "HELLO"
    #
    class AbstractConverter < Utils::SingletonBuilder
      include Singleton

      # @private
      # A registry entry storing a conversion rule.
      #
      # @!attribute klass
      #   @return [Class] the class this rule applies to
      # @!attribute exec
      #   @return [Proc] the block used to convert the object
      Registry = Struct.new(:klass, :exec)

      # @private
      # A sentinel value used to indicate absence of a secondary argument.
      NOTHING = Utils::SingletonBuilder.new('NOTHING')

      # Initializes the builder with a label and optional configuration block.
      def initialize
        super(self.class.to_s)
        @registries = []
        @fallback = Proc.new { |*| self }
        @convert_strategy_map = {}.compare_by_identity
        execute_once_only!(:default_registrations)
      end

      # Applies the registered conversion to the given target object.
      #
      # @param target [Object] the object to convert
      # @param other [Object] optional secondary value
      # @return [Object] converted result
      def convert(target, other = NOTHING)
        convert_strategy = @convert_strategy_map[target.class] ||= find_strategy(target)

        if other == NOTHING
          target.instance_exec(&convert_strategy)
        else
          target.instance_exec(other, &convert_strategy)
        end
      end

      def find_strategy(target)
        @registries.each do |registry|
          next unless target.is_a?(registry.klass)

          return registry.exec
        end

        @fallback
      end

      # Opens a configuration block to register more converters.
      #
      # @yield DSL block to configure more rules
      # @return [void]
      def configure
        yield self
        freeze
      end

      # Freezes all internal registries.
      #
      # @return [void]
      def freeze
        super
        @registries.freeze
      end

      # Registers a conversion rule for a given class.
      #
      # @param klass [Class, Module] the target class
      # @param converter [Symbol, nil] method name to call as a conversion
      # @yield [*args] block that performs the conversion
      # @return [void]
      # @raise [RuntimeError] if input is invalid
      def register(klass, converter = nil, &block)
        raise 'converter or block is required.' if [converter, block].compact.empty?
        raise 'A class or module is reuqired.' unless klass.is_a?(Module)

        if converter.is_a?(Symbol)
          register(klass) { |*args, &bl| send(converter, *args, &bl) }
        elsif block.is_a?(Proc)
          @registries.unshift(Registry.new(klass, block))
          @convert_strategy_map[klass] = block
        else
          raise 'Support Symbol and block only.'
        end
      end

      # Executes the given method only once by undefining it after execution.
      #
      # @param method_sym [Symbol] method name to execute once
      # @return [void]
      def execute_once_only!(method_sym)
        send(method_sym)
        singleton_class.undef_method(method_sym)
      end

      # Defines default class-to-converter registrations.
      # Should be overridden by subclasses.
      #
      # @return [void]
      def default_registrations; end
    end
  end
end
