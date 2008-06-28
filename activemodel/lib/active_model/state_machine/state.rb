module ActiveModel
  module StateMachine
    class State
      attr_reader :name, :options

      def initialize(machine, name, options={})
        @machine, @name, @options, @display_name = machine, name, options, options.delete(:display)
        machine.klass.send(:define_method, "#{name}?") do
          current_state.to_s == name.to_s
        end
      end

      def ==(state)
        if state.is_a? Symbol
          name == state
        else
          name == state.name
        end
      end

      def call_action(action, record)
        action = @options[action]
        case action
        when Symbol, String
          record.send(action)
        when Proc
          action.call(record)
        end
      end

      def display_name
        @display_name ||= name.to_s.gsub(/_/, ' ').capitalize
      end

      def for_select
        [display_name, name.to_s]
      end
    end
  end
end
