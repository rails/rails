require 'observer'
require 'singleton'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array/wrap'

module ActiveModel
  module Observing
    extend ActiveSupport::Concern

    included do
      extend Observable
    end

    module ClassMethods
      # Activates the observers assigned. Examples:
      #
      #   # Calls PersonObserver.instance
      #   ActiveRecord::Base.observers = :person_observer
      #
      #   # Calls Cacher.instance and GarbageCollector.instance
      #   ActiveRecord::Base.observers = :cacher, :garbage_collector
      #
      #   # Same as above, just using explicit class references
      #   ActiveRecord::Base.observers = Cacher, GarbageCollector
      #
      # Note: Setting this does not instantiate the observers yet. +instantiate_observers+ is
      # called during startup, and before each development request.
      def observers=(*values)
        @observers = values.flatten
      end

      # Gets the current observers.
      def observers
        @observers ||= []
      end

      # Instantiate the global Active Record observers.
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

    private
      def notify(method) #:nodoc:
        self.class.changed
        self.class.notify_observers(method, self)
      end
  end

  class Observer
    include Singleton

    class << self
      # Attaches the observer to the supplied model classes.
      def observe(*models)
        models.flatten!
        models.collect! { |model| model.respond_to?(:to_sym) ? model.to_s.camelize.constantize : model }
        define_method(:observed_classes) { models }
      end

      def observed_classes
        Array.wrap(observed_class)
      end

      # The class observed by default is inferred from the observer's class name:
      #   assert_equal Person, PersonObserver.observed_class
      def observed_class
        if observed_class_name = name[/(.*)Observer/, 1]
          observed_class_name.constantize
        else
          nil
        end
      end
    end

    # Start observing the declared classes and their subclasses.
    def initialize
      observed_classes.each { |klass| add_observer!(klass) }
    end

    def observed_classes
      self.class.observed_classes
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
      def add_observer!(klass)
        klass.add_observer(self)
      end
  end
end
