Dir[File.dirname(__FILE__) + "/state_machine/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_model/state_machine/#{filename}"
end

module ActiveModel
  module StateMachine
    class InvalidTransition < Exception
    end

    def self.included(base)
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
    end

    def current_state(name = nil, new_state = nil)
      sm   = self.class.state_machine(name)
      ivar = "@#{sm.name}_current_state"
      if name && new_state
        instance_variable_set(ivar, new_state)
      else
        instance_variable_get(ivar) || instance_variable_set(ivar, sm.initial_state)
      end
    end
  end
end