module ActiveModel
  module StateMachine
    class InvalidTransition < Exception
    end

    def self.included(base)
      require 'active_model/state_machine/machine'
      base.extend ClassMethods
    end

    module ClassMethods
      def inherited(klass)
        super
        klass.state_machines = state_machines
      end

      def state_machines
        @state_machines ||= {}
      end

      def state_machines=(value)
        @state_machines = value ? value.dup : nil
      end

      def state_machine(name = nil, options = {}, &block)
        if name.is_a?(Hash)
          options = name
          name    = nil
        end
        name ||= :default
        state_machines[name] ||= Machine.new(self, name)
        block ? state_machines[name].update(options, &block) : state_machines[name]
      end

      def define_state_query_method(state_name)
        name = "#{state_name}?"
        undef_method(name) if method_defined?(name)
        class_eval "def #{name}; current_state.to_s == %(#{state_name}) end"
      end
    end

    def current_state(name = nil, new_state = nil, persist = false)
      sm   = self.class.state_machine(name)
      ivar = sm.current_state_variable
      if name && new_state
        if persist && respond_to?(:write_state)
          write_state(sm, new_state)
        end

        if respond_to?(:write_state_without_persistence)
          write_state_without_persistence(sm, new_state)
        end

        instance_variable_set(ivar, new_state)
      else
        instance_variable_set(ivar, nil) unless instance_variable_defined?(ivar)
        value = instance_variable_get(ivar)
        return value if value

        if respond_to?(:read_state)
          value = instance_variable_set(ivar, read_state(sm))
        end

        value || sm.initial_state
      end
    end
  end
end
