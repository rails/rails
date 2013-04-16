require 'active_support/per_thread_registry'

module ActiveRecord
  # This is a thread locals registry for Active Record. For example
  #
  #   ActiveRecord::RuntimeRegistry.connection_handler
  #
  # returns the connection handler local to the current thread.
  #
  # See the documentation of <tt>ActiveSupport::PerThreadRegistry</tt>
  # for further details.
  class RuntimeRegistry
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :connection_handler, :sql_runtime, :connection_id,
                  :available_queries_for_explain, :collecting_queries_flag

    def initialize
      @available_queries_for_explain = []
      @saved_variables               = {}
    end

    # Saves the current +available_queries_for_explain+ and set the flag of
    # +collecting_queries_flag+ to true.
    def save_available_queries
      @collecting_queries_flag = true
      save(:available_queries_for_explain, [])
    end

    # Restores the saved contents of +available_queries_for_explain+ and sets
    # flag of +collecting_queries_flag+ to false.
    def restore_available_queries
      @collecting_queries_flag = false
      restore(:available_queries_for_explain, [])
    end

    # Saves the current value of +variable_name+ into an internal hash inside
    # the +RuntimeRegistry+ object. This allows you to later call +restore+
    # and obtain the old value for the variable and mutate the value between
    # the save and restore calls.
    #
    # Note that if save was called previously, then a new call to save will
    # overwrite the previous saved value.
    #
    # Requires that +variable_name+ be a symbol matching a valid attribute.
    def save(variable_name, reset_value = nil)
      value = instance_variable_get("@#{variable_name}")
      instance_variable_set("@#{variable_name}", reset_value)
      @saved_variables[variable_name] = value
    end

    # Restores the value of +variable_name+ and returns the value. After
    # calling this, the attribute +variable_name+ should be restored to the
    # original value it had when +save+ was called.
    #
    # If there is no stored value, then nil is returned.
    #
    # Requires that +variable_name+ be a symbol matching a valid attribute.
    def restore(variable_name, reset_value = nil)
      stored_value = @saved_variables[variable_name]
      if stored_value
        @saved_variables[variable_name] = reset_value
        instance_variable_set("@#{variable_name}", stored_value)
        stored_value
      end
    end
  end
end
