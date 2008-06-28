module ActiveModel
  module StateMachine
    class Machine
      attr_accessor :initial_state, :states, :events, :state_index
      attr_reader :klass, :name

      def initialize(klass, name, options = {}, &block)
        @klass, @name, @states, @state_index, @events = klass, name, [], {}, {}
        update(options, &block)
      end

      def initial_state
        @initial_state ||= (states.first ? states.first.name : nil)
      end

      def update(options = {}, &block)
        if options.key?(:initial) then @initial_state = options[:initial] end
        if block                  then instance_eval(&block)              end
        self
      end

      def fire_event(name, record, persist, *args)
        state_index[record.current_state].call_action(:exit, record)
        if new_state = @events[name].fire(record, *args)
          state_index[new_state].call_action(:enter, record)
          record.current_state(@name, new_state)
        else
          false
        end
      end

      def states_for_select
        states.map { |st| [st.display_name, st.name.to_s] }
      end

      def events_for(state)
        events = @events.values.select { |event| event.transitions_from_state?(state) }
        events.map! { |event| event.name }
      end
    private
      def state(name, options = {})
        @states << (state_index[name] ||= State.new(name, :machine => self)).update(options)
      end

      def event(name, options = {}, &block)
        (@events[name] ||= Event.new(name, :machine => self)).update(options, &block)
      end
    end
  end
end