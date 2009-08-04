module ActiveModel
  module StateMachine
    class Event
      attr_reader :name, :success

      def initialize(machine, name, options = {}, &block)
        @machine, @name, @transitions = machine, name, []
        if machine
          machine.klass.send(:define_method, "#{name}!") do |*args|
            machine.fire_event(name, self, true, *args)
          end

          machine.klass.send(:define_method, name.to_s) do |*args|
            machine.fire_event(name, self, false, *args)
          end
        end
        update(options, &block)
      end

      def fire(obj, to_state = nil, *args)
        transitions = @transitions.select { |t| t.from == obj.current_state(@machine ? @machine.name : nil) }
        raise InvalidTransition if transitions.size == 0

        next_state = nil
        transitions.each do |transition|
          next if to_state && !Array(transition.to).include?(to_state)
          if transition.perform(obj)
            next_state = to_state || Array(transition.to).first
            transition.execute(obj, *args)
            break
          end
        end
        next_state
      end

      def transitions_from_state?(state)
        @transitions.any? { |t| t.from? state }
      end

      def ==(event)
        if event.is_a? Symbol
          name == event
        else
          name == event.name
        end
      end

      def update(options = {}, &block)
        if options.key?(:success) then @success = options[:success] end
        if block                  then instance_eval(&block)        end
        self
      end

      private
        def transitions(trans_opts)
          Array(trans_opts[:from]).each do |s|
            @transitions << StateTransition.new(trans_opts.merge({:from => s.to_sym}))
          end
        end
    end
  end
end
