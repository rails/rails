require 'singleton'
require 'set'

module ActiveRecord
  module Observing # :nodoc:
    def self.included(base)
      base.extend ClassMethods
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
      # Note: Setting this does not instantiate the observers yet.  #instantiate_observers is
      # called during startup, and before each development request.  
      def observers=(*observers)
        @observers = observers.flatten
      end

      # Gets the current observers.
      def observers
        @observers ||= []
      end

      # Instantiate the global ActiveRecord observers
      def instantiate_observers
        return if @observers.blank?
        @observers.each do |observer|
          if observer.respond_to?(:to_sym) # Symbol or String
            observer.to_s.camelize.constantize.instance
          elsif observer.respond_to?(:instance)
            observer.instance
          else
            raise ArgumentError, "#{observer} must be a lowercase, underscored class name (or an instance of the class itself) responding to the instance method. Example: Person.observers = :big_brother # calls BigBrother.instance"
          end
        end
      end

      protected
        # Notify observers when the observed class is subclassed.
        def inherited(subclass)
          super
          changed
          notify_observers :observed_class_inherited, subclass
        end
    end
  end

  # Observer classes respond to lifecycle callbacks to implement trigger-like
  # behavior outside the original class. This is a great way to reduce the
  # clutter that normally comes when the model class is burdened with
  # functionality that doesn't pertain to the core responsibility of the
  # class. Example:
  #
  #   class CommentObserver < ActiveRecord::Observer
  #     def after_save(comment)
  #       Notifications.deliver_comment("admin@do.com", "New comment was posted", comment)
  #     end
  #   end
  #
  # This Observer sends an email when a Comment#save is finished.
  #
  #   class ContactObserver < ActiveRecord::Observer
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
  # Observers will by default be mapped to the class with which they share a name. So CommentObserver will
  # be tied to observing Comment, ProductManagerObserver to ProductManager, and so on. If you want to name your observer
  # differently than the class you're interested in observing, you can use the Observer.observe class method:
  #
  #   class AuditObserver < ActiveRecord::Observer
  #     observe Account
  #
  #     def after_update(account)
  #       AuditTrail.new(account, "UPDATED")
  #     end
  #   end
  #
  # If the audit observer needs to watch more than one kind of object, this can be specified with multiple arguments:
  #
  #   class AuditObserver < ActiveRecord::Observer
  #     observe Account, Balance
  #
  #     def after_update(record)
  #       AuditTrail.new(record, "UPDATED")
  #     end
  #   end
  #
  # The AuditObserver will now act on both updates to Account and Balance by treating them both as records.
  #
  # == Available callback methods
  #
  # The observer can implement callback methods for each of the methods described in the Callbacks module.
  #
  # == Storing Observers in Rails
  #
  # If you're using Active Record within Rails, observer classes are usually stored in app/models with the
  # naming convention of app/models/audit_observer.rb.
  #
  # == Configuration
  #
  # In order to activate an observer, list it in the <tt>config.active_record.observers</tt> configuration setting in your
  # <tt>config/environment.rb</tt> file.
  #
  #   config.active_record.observers = :comment_observer, :signup_observer
  #
  # Observers will not be invoked unless you define these in your application configuration.
  #
  class Observer
    include Singleton

    # Observer subclasses should be reloaded by the dispatcher in Rails
    # when Dependencies.mechanism = :load.
    include Reloadable::Deprecated

    class << self
      # Attaches the observer to the supplied model classes.
      def observe(*models)
        define_method(:observed_classes) { Set.new(models) }
      end

      # The class observed by default is inferred from the observer's class name:
      #   assert_equal [Person], PersonObserver.observed_class
      def observed_class
        name.scan(/(.*)Observer/)[0][0].constantize
      end
    end

    # Start observing the declared classes and their subclasses.
    def initialize
      Set.new(observed_classes + observed_subclasses).each { |klass| add_observer! klass }
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
        Set.new([self.class.observed_class].flatten)
      end

      def observed_subclasses
        observed_classes.sum(&:subclasses)
      end

      def add_observer!(klass)
        klass.add_observer(self)
        klass.class_eval 'def after_find() end' unless klass.respond_to?(:after_find)
      end
  end
end
