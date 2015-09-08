module ActiveModel
  # :stopdoc:
  module Type
    class Registry
      def initialize
        @registrations = []
      end

      def register(type_name, klass = nil, **options, &block)
        block ||= proc { |_, *args| klass.new(*args) }
        registrations << registration_klass.new(type_name, block, **options)
      end

      def lookup(symbol, *args)
        registration = registrations
          .select { |r| r.matches?(symbol, *args) }
          .max

        if registration
          registration.call(self, symbol, *args)
        else
          raise ArgumentError, "Unknown type #{symbol.inspect}"
        end
      end

      def add_modifier(options, klass, **args)
        registrations << decoration_registration_klass.new(options, klass, **args)
      end

      protected

      attr_reader :registrations
      
      private
      
      def registration_klass
        Registration
      end
      
      def decoration_registration_klass
        DecorationRegistration
      end
    end

    class Registration
      def initialize(name, block, override: nil)
        @name = name
        @block = block
        @override = override
      end

      def call(_registry, *args, **kwargs)
        if kwargs.any? # https://bugs.ruby-lang.org/issues/10856
          block.call(*args, **kwargs)
        else
          block.call(*args)
        end
      end

      def matches?(type_name, *args, **kwargs)
        type_name == name# && matches_adapter?(**kwargs)
      end

      def <=>(other)
        # if conflicts_with?(other)
        #   raise TypeConflictError.new("Type #{name} was registered for all
        #                               adapters, but shadows a native type with
        #                               the same name for #{other.adapter}".squish)
        # end
        priority <=> other.priority
      end

      protected

      attr_reader :name, :block, :override

      def priority
        result = 0
        # if adapter
        #   result |= 1
        # end
        if override
          result |= 2
        end
        result
      end

      # def priority_except_adapter
      #   priority & 0b111111100
      # end

      private

      # def matches_adapter?(adapter: nil, **)
      #   (self.adapter.nil? || adapter == self.adapter)
      # end

      # def conflicts_with?(other)
      #   same_priority_except_adapter?(other) &&
      #     has_adapter_conflict?(other)
      # end

      # def same_priority_except_adapter?(other)
      #   priority_except_adapter == other.priority_except_adapter
      # end

      # def has_adapter_conflict?(other)
      #   (override.nil? && other.adapter) ||
      #     (adapter && other.override.nil?)
      # end
    end

    class DecorationRegistration < Registration
      def initialize(options, klass)
        @options = options
        @klass = klass
        # @adapter = adapter
      end

      def call(registry, *args, **kwargs)
        subtype = registry.lookup(*args, **kwargs.except(*options.keys))
        klass.new(subtype)
      end

      def matches?(*args, **kwargs)
        matches_options?(**kwargs)
      end

      def priority
        super | 4
      end

      protected

      attr_reader :options, :klass

      private

      def matches_options?(**kwargs)
        options.all? do |key, value|
          kwargs[key] == value
        end
      end
    end
  end

  class TypeConflictError < StandardError
  end

  # :startdoc:
end
