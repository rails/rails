require 'active_support/per_thread_registry'

module ActiveRecord
  # This is a registry class for storing local variables in Active Record. The
  # class allows you to access variables that are local to the current thread.
  # These thread local variables are stored as attributes in the
  # +RuntimeRegistry+ class.
  #
  # You can access the thread local variables by calling a variable's name on
  # the +RuntimeRegistry+ class. For example, if you wanted to obtain the
  # connection handler for the current thread, you would invoke:
  #
  #   ActiveRecord::RuntimeRegistry.instance.connection_handler
  #
  # The +PerThreadRegistry+ module will make a new +RuntimeRegistry+ instance
  # and store it in +Thread.current+. Whenever you make a call for an attribute
  # on the +RuntimeRegistry+ class, the call will be sent to the instance that
  # is stored in +Thread.current+.
  #
  # Note that you can also make the following call which would provide an
  # equivalent result as the previous code:
  #
  #   ActiveRecord::RuntimeRegistry.connection_handler
  #
  # However, this is less performant because it makes a call to +method_missing+
  # before it sends the method call to the +instance+.
  class RuntimeRegistry
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :connection_handler, :sql_runtime, :connection_id
  end
end
