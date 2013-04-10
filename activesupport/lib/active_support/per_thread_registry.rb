module ActiveSupport
  # This module creates a local registry class inside each thread. It provides
  # basic methods which will store thread locals in a single class. This
  # prevents the proliferation of too many thread locals and allows you to
  # explicitly keep track of each of the variables you're using as thread
  # locals in a class which includes this module.
  #
  # For example, instead of using a bunch of different thread locals to keep
  # track of some variables like so:
  #
  #   Thread.current[:active_record_connection_handler] = connection_handler
  #   Thread.current[:active_record_sql_runtime]        = sql_runtime
  #
  # You could use the following class which implements the +PerThreadRegistry+
  # module:
  #
  #   class NewRegistry
  #     extend ActiveSupport::PerThreadRegistry
  #
  #     attr_accessor :connection_handler, :sql_runtime
  #   end
  #
  #   NewRegistry.instance.connection_handler = connection_handler
  #   NewRegistry.instance.sql_runtime        = sql_runtime
  #
  # The new way of keeping track of the thread locals will create a new local
  # inside of +Thread.current+ with a key which is the name of the extended
  # class. Now you can easily access per thread variables by just calling the
  # variable name on the registry.
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
