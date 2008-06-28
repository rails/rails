module ActiveModel
  module StateMachine
    class Machine
      attr_accessor :initial_state, :states, :event
      attr_reader :klass, :name

      def initialize(klass, name)
        @klass, @name, @states, @events = klass, name, [], {}
      end

      def states_for_select
        states.map { |st| [st.display_name, st.name.to_s] }
      end

      def state(name, options = {})
        @states << State.new(self, name, options)
      end

      def initial_state
        @initial_state ||= (states.first ? states.first.name : nil)
      end

      def update(options = {}, &block)
        @initial_state = options[:initial]
        instance_eval(&block)
        self
      end
    end
  end
end