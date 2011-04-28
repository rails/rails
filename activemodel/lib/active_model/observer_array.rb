require 'set'

module ActiveModel
  # Stores the enabled/disabled state of individual observers for
  # a particular model classes.
  class ObserverArray < Array
    attr_reader :model_class
    def initialize(model_class, *args)
      @model_class = model_class
      super(*args)
    end

    def disabled_for?(observer)
      disabled_observers.include?(observer.class)
    end

    def disable(*observers, &block)
      set_enablement(false, observers, &block)
    end

    def enable(*observers, &block)
      set_enablement(true, observers, &block)
    end

    protected

      def disabled_observers
        @disabled_observers ||= Set.new
      end

      def observer_class_for(observer)
        return observer if observer.is_a?(Class)

        if observer.respond_to?(:to_sym) # string/symbol
          observer.to_s.camelize.constantize
        else
          raise ArgumentError, "#{observer} was not a class or a " +
            "lowercase, underscored class name as expected."
        end
      end

      def start_transaction
        disabled_observer_stack.push(disabled_observers.dup)
        each_subclass_array do |array|
          array.start_transaction
        end
      end

      def disabled_observer_stack
        @disabled_observer_stack ||= []
      end

      def end_transaction
        @disabled_observers = disabled_observer_stack.pop
        each_subclass_array do |array|
          array.end_transaction
        end
      end

      def transaction
        start_transaction

        begin
          yield
        ensure
          end_transaction
        end
      end

      def each_subclass_array
        model_class.descendants.each do |subclass|
          yield subclass.observers
        end
      end

      def set_enablement(enabled, observers)
        if block_given?
          transaction do
            set_enablement(enabled, observers)
            yield
          end
        else
          observers = ActiveModel::Observer.descendants if observers == [:all]
          observers.each do |obs|
            klass = observer_class_for(obs)

            unless klass < ActiveModel::Observer
              raise ArgumentError.new("#{obs} does not refer to a valid observer")
            end

            if enabled
              disabled_observers.delete(klass)
            else
              disabled_observers << klass
            end
          end

          each_subclass_array do |array|
            array.set_enablement(enabled, observers)
          end
        end
      end
  end
end
