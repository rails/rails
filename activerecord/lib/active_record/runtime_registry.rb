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
                  :available_queries_for_explain

    def initialize
      @available_queries_for_explain = []
      @saved_variables               = {}
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
    def save(variable_name)
      value = instance_variable_get("@#{variable_name}")
      instance_variable_set("@#{variable_name}", reset_value(variable_name))
      @saved_variables[variable_name] = value
    end

    # Restores the value of +variable_name+ and returns the value. After
    # calling this, the attribute +variable_name+ should be restored to the
    # original value it had when +save+ was called.
    #
    # If there is no stored value, then nil is returned.
    #
    # Requires that +variable_name+ be a symbol matching a valid attribute.
    def restore(variable_name)
      stored_value = @saved_variables[variable_name]
      if stored_value
        @saved_variables[variable_name] = reset_value(variable_name)
        instance_variable_set("@#{variable_name}", stored_value)
        stored_value
      end
    end

    private

      # The reset value will be nil unless the variable name passed in is
      # +available_queries_for_explain+, in which case we pass back an empty
      # array as the reset value.
      def reset_value(variable_name)
        if variable_name == :available_queries_for_explain
          []
        end
      end
  end
end
