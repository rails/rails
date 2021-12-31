# frozen_string_literal: true

module ActiveRecord
  # :stopdoc:
  module Type
    class AdapterSpecificRegistry # :nodoc:
      def initialize
        @registrations = []
      end

      def initialize_copy(other)
        @registrations = @registrations.dup
      end

      def add_modifier(options, klass, **args)
        registrations << DecorationRegistration.new(options, klass, **args)
      end

      def register(type_name, klass = nil, **options, &block)
        unless block_given?
          block = proc { |_, *args| klass.new(*args) }
          block.ruby2_keywords if block.respond_to?(:ruby2_keywords)
        end
        registrations << Registration.new(type_name, block, **options)
      end

      def lookup(symbol, *args, **kwargs)
        registration = find_registration(symbol, *args, **kwargs)

        if registration
          registration.call(self, symbol, *args, **kwargs)
        else
          raise ArgumentError, "Unknown type #{symbol.inspect}"
        end
      end

      private
        attr_reader :registrations

        def find_registration(symbol, *args, **kwargs)
          registrations
            .select { |registration| registration.matches?(symbol, *args, **kwargs) }
            .max
        end
    end

    class Registration # :nodoc:
      def initialize(name, block, adapter: nil, override: nil)
        @name = name
        @block = block
        @adapter = adapter
        @override = override
      end

      def call(_registry, *args, adapter: nil, **kwargs)
        block.call(*args, **kwargs)
      end

      def matches?(type_name, *args, **kwargs)
        type_name == name && matches_adapter?(**kwargs)
      end

      def <=>(other)
        if conflicts_with?(other)
          raise TypeConflictError.new("Type #{name} was registered for all
                                      adapters, but shadows a native type with
                                      the same name for #{other.adapter}".squish)
        end
        priority <=> other.priority
      end

      protected
        attr_reader :name, :block, :adapter, :override

        def priority
          result = 0
          if adapter
            result |= 1
          end
          if override
            result |= 2
          end
          result
        end

        def priority_except_adapter
          priority & 0b111111100
        end

      private
        def matches_adapter?(adapter: nil, **)
          (self.adapter.nil? || adapter == self.adapter)
        end

        def conflicts_with?(other)
          same_priority_except_adapter?(other) &&
            has_adapter_conflict?(other)
        end

        def same_priority_except_adapter?(other)
          priority_except_adapter == other.priority_except_adapter
        end

        def has_adapter_conflict?(other)
          (override.nil? && other.adapter) ||
            (adapter && other.override.nil?)
        end
    end

    class DecorationRegistration < Registration # :nodoc:
      def initialize(options, klass, adapter: nil)
        @options = options
        @klass = klass
        @adapter = adapter
      end

      def call(registry, *args, **kwargs)
        subtype = registry.lookup(*args, **kwargs.except(*options.keys))
        klass.new(subtype)
      end

      def matches?(*args, **kwargs)
        matches_adapter?(**kwargs) && matches_options?(**kwargs)
      end

      def priority
        super | 4
      end

      private
        attr_reader :options, :klass

        def matches_options?(**kwargs)
          options.all? do |key, value|
            kwargs[key] == value
          end
        end
    end
  end

  class TypeConflictError < StandardError # :nodoc:
  end
  # :startdoc:
end
