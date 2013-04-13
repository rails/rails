module ActiveSupport
  # This module is used to encapsulate access to thread local variables.
  #
  # Given
  #
  #   module ActiveRecord
  #     class RuntimeRegistry
  #       extend ActiveSupport::PerThreadRegistry
  #
  #       attr_accessor :connection_handler
  #     end
  #   end
  #
  # <tt>ActiveRecord::RuntimeRegistry</tt> gets an +instance+ class method
  # that returns an instance of the class unique to the current thread. Thus,
  # instead of polluting +Thread.current+
  #
  #   Thread.current[:connection_handler]
  #
  # you write
  #
  #   ActiveRecord::RuntimeRegistry.instance.connection_handler
  #
  # A +method_missing+ handler that proxies to the thread local instance is
  # installed in the extended class so the call above can be shortened to
  #
  #   ActiveRecord::RuntimeRegistry.connection_handler
  #
  # The instance is stored as a thread local keyed by the name of the class,
  # that is the string "ActiveRecord::RuntimeRegistry" in the example above.
  #
  # If the class has an initializer, it must accept no arguments.
  module PerThreadRegistry
    def instance
      Thread.current[self.name] ||= new
    end

    protected

      def method_missing(*args, &block)
        instance.public_send(*args, &block)
      end
  end
end
