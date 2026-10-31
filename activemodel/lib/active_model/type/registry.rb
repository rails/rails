# frozen_string_literal: true

module ActiveModel
  module Type
    class Registry # :nodoc:
      def initialize
        @registrations = {}
      end

      def initialize_copy(other)
        @registrations = @registrations.dup
        super
      end

      def register(type_name, klass = nil, &block)
        block ||= proc { |_, *args, **kwargs| klass.new(*args, **kwargs) }
        registrations[type_name] = block
      end

      def lookup(symbol, ...)
        registration = registrations[symbol]

        if registration
          registration.call(symbol, ...)
        else
          raise ArgumentError, "Unknown type #{symbol.inspect}"
        end
      end

      private
        attr_reader :registrations
    end
  end
end
