require 'observer'

module ActiveModel
  module Observing
    module ClassMethods
      def observers
        @observers ||= []
      end
      
      def observers=(*values)
        @observers = values.flatten
      end
      
      def instantiate_observers
        observers.each { |o| instantiate_observer(o) }
      end
    
    protected
      def instantiate_observer(observer)
        # string/symbol
        if observer.respond_to?(:to_sym)
          observer = observer.to_s.camelize.constantize.instance
        elsif observer.respond_to?(:instance)
          observer.instance
        else
          raise ArgumentError, "#{observer} must be a lowercase, underscored class name (or an instance of the class itself) responding to the instance method. Example: Person.observers = :big_brother # calls BigBrother.instance"
        end
      end
      
      # Notify observers when the observed class is subclassed.
      def inherited(subclass)
        super
        changed
        notify_observers :observed_class_inherited, subclass
      end
    end
    
    def self.included(receiver)
      receiver.extend Observable, ClassMethods
    end
  end

  class Observer
    include Singleton
    attr_writer :observed_classes

    class << self
      attr_accessor :models
      # Attaches the observer to the supplied model classes.
      def observe(*models)
        @models = models.flatten
        @models.collect! { |model| model.respond_to?(:to_sym) ? model.to_s.camelize.constantize : model }
      end

      def observed_class_name
        @observed_class_name ||= 
          if guessed_name = name.scan(/(.*)Observer/)[0]
            @observed_class_name = guessed_name[0]
          end
      end

      # The class observed by default is inferred from the observer's class name:
      #   assert_equal [Person], PersonObserver.observed_class
      def observed_class
        if observed_class_name
          observed_class_name.constantize
        else
          nil
        end
      end
    end

    # Start observing the declared classes and their subclasses.
    def initialize
      self.observed_classes = self.class.models if self.class.models
      observed_classes.each { |klass| add_observer! klass }
    end

    # Send observed_method(object) if the method exists.
    def update(observed_method, object) #:nodoc:
      send(observed_method, object) if respond_to?(observed_method)
    end

    # Special method sent by the observed class when it is inherited.
    # Passes the new subclass.
    def observed_class_inherited(subclass) #:nodoc:
      self.class.observe(observed_classes + [subclass])
      add_observer!(subclass)
    end

    protected
      def observed_classes
        @observed_classes ||= [self.class.observed_class]
      end

      def add_observer!(klass)
        klass.add_observer(self)
      end
  end
end