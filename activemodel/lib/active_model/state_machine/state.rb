module ActiveModel
  module StateMachine
    class State
      attr_reader :name, :options

      def initialize(name, options = {})
        @name = name
        machine = options.delete(:machine)
        if machine
          machine.klass.send(:define_method, "#{name}?") do
            current_state.to_s == name.to_s
          end
        end
        update(options)
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

      def update(options = {})
        if options.key?(:display) then @display_name = options.delete(:display) end
        @options = options
        self
      end
    end
  end
end
