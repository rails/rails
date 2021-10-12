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
        unless block_given?
          block = proc { |_, *args| klass.new(*args) }
          block.ruby2_keywords if block.respond_to?(:ruby2_keywords)
        end
        registrations[type_name] = block
      end

      def lookup(symbol, *args)
        registration = registrations[symbol]

        if registration
          registration.call(symbol, *args)
        else
          raise ArgumentError, "Unknown type #{symbol.inspect}"
        end
      end
      ruby2_keywords(:lookup)

      private
        attr_reader :registrations
    end
  end
end
