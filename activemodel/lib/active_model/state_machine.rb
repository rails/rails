module ActiveModel
  
  # ActiveModel::StateMachine provides methods that turn your object into a
  # finite state machine, able to move from one state to another.
  # 
  # A minimal implementation could be:
  # 
  #    class EmailMessage
  #      include ActiveModel::StateMachine
  #    
  #      state_machine do
  #        state :unread
  #        state :read
  #      end
  #    
  #      event :open_email do
  #        transitions :to => :read, :from => :unread
  #      end
  #    end
  # 
  # === Examples
  #
  #   class TrafficLight
  #     include ActiveModel::StateMachine
  #   
  #     attr_reader :runners_caught
  #   
  #     def initialize
  #        @runners_caught = 0
  #      end
  #   
  #     state_machine do
  #       state :red
  #       state :green
  #       state :yellow
  #       state :blink
  #   
  #       event :change_color do
  #         transitions :to => :red, :from => [:yellow],
  #           :on_transition => :catch_runners
  #         transitions :to => :green, :from => [:red]
  #         transitions :to => :yellow, :from => [:green]
  #       end
  #   
  #       event :defect do
  #         transitions :to => :blink, :from => [:yellow, :red, :green]
  #       end
  #   
  #       event :repair do
  #         transitions :to => :red, :from => [:blink]
  #       end
  #     end
  #   
  #     def catch_runners
  #       @runners_caught += 1
  #     end
  #   end
  #   
  #   light = TrafficLight.new
  #   light.current_state        # => :red
  #   light.change_color!        # => true
  #   light.current_state        # => :green
  #   light.green?               # => true
  #   light.change_color!        # => true
  #   light.current_state        # => :yellow
  #   light.red?                 # => false
  #   light.change_color!        # => true
  #   light.runners_caught       # => 1
  # 
  # * The initial state for TrafficLight is red which is the first state defined.
  #
  #    TrafficLight.state_machine.initial_state      # => :red
  #
  # * Call an event to transition a state machine, e.g. <tt>change_color!</tt>.
  #   You can call the event with or without the exclamation mark, however, the common Ruby
  #   idiom is to name methods that directly change the state of the receivier with
  #   an exclamation mark, so <tt>change_color!</tt> is preferred over <tt>change_color</tt>.
  #    
  #    light.current_state    #=> :green
  #    light.change_color!    #=> true
  #    light.current_state    #=> :yellow
  # 
  # * On a succesful transition to red (from yellow), the local +catch_runners+
  #   method is executed
  #
  #    light.current_state    #=> :red
  #    light.change_color!    #=> true
  #    light.runners_caught   #=> 1
  #
  # * The object acts differently depending on its current state, for instance,
  #   the change_color! method has a different action depending on the current
  #   color of the light
  # 
  #    light.change_color!    #=> true
  #    light.current_state    #=> :red
  #    light.change_color!    #=> true
  #    light.current_state    #=> :green
  #
  # * Get the possible events for a state
  #
  #    TrafficLight.state_machine.events_for(:red)   # => [:change_color, :defect]
  #    TrafficLight.state_machine.events_for(:blink) # => [:repair]
  #
  # The StateMachine also supports the following features :
  #
  # * Success callbacks on event transition
  #
  #    event :sample, :success => :we_win do
  #      ...
  #    end
  #
  # * Enter and exit callbacks par state
  #
  #    state :open, :enter => [:alert_twitter, :send_emails], :exit => :alert_twitter
  #
  # * Guards on transition
  #
  #    event :close do
  #      # You may only close the store if the safe is locked!!
  #      transitions :to => :closed, :from => :open, :guard => :safe_locked?
  #    end
  #
  # * Setting the initial state
  #
  #    state_machine :initial => :yellow do
  #      ...
  #    end
  #
  # * Named the state machine, to have more than one
  #
  #    class Stated
  #      include ActiveModel::StateMachine
  #    
  #      strate_machine :name => :ontest do
  #      end
  #    
  #      state_machine do
  #      end
  #    end
  #     
  #    # Get the state of the <tt>:ontest</tt> state machine
  #    stat.current_state(:ontest)
  #    # Get the initial state
  #    Stated.state_machine(:ontest).initial_state
  #
  # * Changing the state
  #
  #    stat.current_state(:default, :astate)    # => :astate
  #    # But you must give the name of the state machine, here <tt>:default</tt>
  #
  module StateMachine
    autoload :Event, 'active_model/state_machine/event'
    autoload :Machine, 'active_model/state_machine/machine'
    autoload :State, 'active_model/state_machine/state'
    autoload :StateTransition, 'active_model/state_machine/state_transition'

    extend ActiveSupport::Concern

    class InvalidTransition < Exception
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
