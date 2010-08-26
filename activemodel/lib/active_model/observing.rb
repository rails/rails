require 'singleton'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/string/inflections'

module ActiveModel
  module Observing
    extend ActiveSupport::Concern

    module ClassMethods
      # == Active Model Observers Activation
      #
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
      # Note: Setting this does not instantiate the observers yet.
      # +instantiate_observers+ is called during startup, and before
      # each development request.
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

      def add_observer(observer)
        unless observer.respond_to? :update
          raise ArgumentError, "observer needs to respond to `update'"
        end
        @observer_instances ||= []
        @observer_instances << observer
      end

      def notify_observers(*arg)
        if defined? @observer_instances
          for observer in @observer_instances
            observer.update(*arg)
          end
        end
      end

      def count_observers
        @observer_instances.size
      end

      protected
        def instantiate_observer(observer) #:nodoc:
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
          notify_observers :observed_class_inherited, subclass
        end
    end

    private
      # Fires notifications to model's observers
      #
      # def save
      #   notify_observers(:before_save)
      #   ...
      #   notify_observers(:after_save)
      # end
      def notify_observers(method)
        self.class.notify_observers(method, self)
      end
  end

  # == Active Model Observers
  #
  # Observer classes respond to life cycle callbacks to implement trigger-like
  # behavior outside the original class. This is a great way to reduce the
  # clutter that normally comes when the model class is burdened with
  # functionality that doesn't pertain to the core responsibility of the
  # class. Example:
  #
  #   class CommentObserver < ActiveModel::Observer
  #     def after_save(comment)
  #       Notifications.deliver_comment("admin@do.com", "New comment was posted", comment)
  #     end
  #   end
  #
  # This Observer sends an email when a Comment#save is finished.
  #
  #   class ContactObserver < ActiveModel::Observer
  #     def after_create(contact)
  #       contact.logger.info('New contact added!')
  #     end
  #
  #     def after_destroy(contact)
  #       contact.logger.warn("Contact with an id of #{contact.id} was destroyed!")
  #     end
  #   end
  #
  # This Observer uses logger to log when specific callbacks are triggered.
  #
  # == Observing a class that can't be inferred
  #
  # Observers will by default be mapped to the class with which they share a
  # name. So CommentObserver will be tied to observing Comment, ProductManagerObserver
  # to ProductManager, and so on. If you want to name your observer differently than
  # the class you're interested in observing, you can use the Observer.observe class
  # method which takes either the concrete class (Product) or a symbol for that
  # class (:product):
  #
  #   class AuditObserver < ActiveModel::Observer
  #     observe :account
  #
  #     def after_update(account)
  #       AuditTrail.new(account, "UPDATED")
  #     end
  #   end
  #
  # If the audit observer needs to watch more than one kind of object, this can be
  # specified with multiple arguments:
  #
  #   class AuditObserver < ActiveModel::Observer
  #     observe :account, :balance
  #
  #     def after_update(record)
  #       AuditTrail.new(record, "UPDATED")
  #     end
  #   end
  #
  # The AuditObserver will now act on both updates to Account and Balance by treating
  # them both as records.
  #
  class Observer
    include Singleton

    class << self
      # Attaches the observer to the supplied model classes.
      def observe(*models)
        models.flatten!
        models.collect! { |model| model.respond_to?(:to_sym) ? model.to_s.camelize.constantize : model }
        remove_possible_method(:observed_classes)
        define_method(:observed_classes) { models }
      end

      # Returns an array of Classes to observe.
      #
      # You can override this instead of using the +observe+ helper.
      #
      #   class AuditObserver < ActiveModel::Observer
      #     def self.observed_classes
      #       [Account, Balance]
      #     end
      #   end
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

    def observed_classes #:nodoc:
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
      def add_observer!(klass) #:nodoc:
        klass.add_observer(self)
      end
  end
end
