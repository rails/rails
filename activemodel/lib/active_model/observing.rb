require 'singleton'
require 'active_model/observer_array'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/object/try'
require 'active_support/descendants_tracker'

module ActiveModel
  # == Active Model Observers Activation
  module Observing
    extend ActiveSupport::Concern

    included do
      extend ActiveSupport::DescendantsTracker
    end

    module ClassMethods
      # Activates the observers assigned.
      #
      #   class ORM
      #     include ActiveModel::Observing
      #   end
      #
      #   # Calls PersonObserver.instance
      #   ORM.observers = :person_observer
      #
      #   # Calls Cacher.instance and GarbageCollector.instance
      #   ORM.observers = :cacher, :garbage_collector
      #
      #   # Same as above, just using explicit class references
      #   ORM.observers = Cacher, GarbageCollector
      #
      # Note: Setting this does not instantiate the observers yet.
      # <tt>instantiate_observers</tt> is called during startup, and before
      # each development request.
      def observers=(*values)
        observers.replace(values.flatten)
      end

      # Gets an array of observers observing this model. The array also provides
      # +enable+ and +disable+ methods that allow you to selectively enable and
      # disable observers (see ActiveModel::ObserverArray.enable and
      # ActiveModel::ObserverArray.disable for more on this).
      #
      #   class ORM
      #     include ActiveModel::Observing
      #   end
      #
      #   ORM.observers = :cacher, :garbage_collector
      #   ORM.observers       # => [:cacher, :garbage_collector]
      #   ORM.observers.class # => ActiveModel::ObserverArray
      def observers
        @observers ||= ObserverArray.new(self)
      end

      # Returns the current observer instances.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #
      #     attr_accessor :status
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #     def on_spec(record, *args)
      #       record.status = true
      #     end
      #   end
      #
      #   Foo.observers = FooObserver
      #   Foo.instantiate_observers
      #
      #   Foo.observer_instances # => [#<FooObserver:0x007fc212c40820>]
      def observer_instances
        @observer_instances ||= []
      end

      # Instantiate the global observers.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #
      #     attr_accessor :status
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #     def on_spec(record, *args)
      #       record.status = true
      #     end
      #   end
      #
      #   Foo.observers = FooObserver
      #
      #   foo = Foo.new
      #   foo.status = false
      #   foo.notify_observers(:on_spec)
      #   foo.status # => false
      #
      #   Foo.instantiate_observers # => [FooObserver]
      #
      #   foo = Foo.new
      #   foo.status = false
      #   foo.notify_observers(:on_spec)
      #   foo.status # => true
      def instantiate_observers
        observers.each { |o| instantiate_observer(o) }
      end

      # Add a new observer to the pool. The new observer needs to respond to
      # <tt>update</tt>, otherwise it raises an +ArgumentError+ exception.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #   end
      #
      #   Foo.add_observer(FooObserver.instance)
      #
      #   Foo.observers_instance
      #   # => [#<FooObserver:0x007fccf55d9390>]
      def add_observer(observer)
        unless observer.respond_to? :update
          raise ArgumentError, "observer needs to respond to 'update'"
        end
        observer_instances << observer
      end

      # Fires notifications to model's observers.
      #
      #   def save
      #     notify_observers(:before_save)
      #     ...
      #     notify_observers(:after_save)
      #   end
      #
      # Custom notifications can be sent in a similar fashion:
      #
      #   notify_observers(:custom_notification, :foo)
      #
      # This will call <tt>custom_notification</tt>, passing as arguments
      # the current object and <tt>:foo</tt>.
      def notify_observers(*args)
        observer_instances.each { |observer| observer.update(*args) }
      end

      # Returns the total number of instantiated observers.
      #
      #   class Foo
      #     include ActiveModel::Observing
      #
      #     attr_accessor :status
      #   end
      #
      #   class FooObserver < ActiveModel::Observer
      #     def on_spec(record, *args)
      #       record.status = true
      #     end
      #   end
      #
      #   Foo.observers = FooObserver
      #   Foo.observers_count # => 0
      #   Foo.instantiate_observers
      #   Foo.observers_count # => 1
      def observers_count
        observer_instances.size
      end

      # <tt>count_observers</tt> is deprecated. Use #observers_count.
      def count_observers
        msg = "count_observers is deprecated in favor of observers_count"
        ActiveSupport::Deprecation.warn(msg)
        observers_count
      end

      protected
        def instantiate_observer(observer) #:nodoc:
          # string/symbol
          if observer.respond_to?(:to_sym)
            observer = observer.to_s.camelize.constantize
          end
          if observer.respond_to?(:instance)
            observer.instance
          else
            raise ArgumentError,
              "#{observer} must be a lowercase, underscored class name (or " +
              "the class itself) responding to the method :instance. " +
              "Example: Person.observers = :big_brother # calls " +
              "BigBrother.instance"
          end
        end

        # Notify observers when the observed class is subclassed.
        def inherited(subclass) #:nodoc:
          super
          notify_observers :observed_class_inherited, subclass
        end
    end

    # Notify a change to the list of observers.
    #
    #   class Foo
    #     include ActiveModel::Observing
    #
    #     attr_accessor :status
    #   end
    #
    #   class FooObserver < ActiveModel::Observer
    #     def on_spec(record, *args)
    #       record.status = true
    #     end
    #   end
    #
    #   Foo.observers = FooObserver
    #   Foo.instantiate_observers # => [FooObserver]
    #
    #   foo = Foo.new
    #   foo.status = false
    #   foo.notify_observers(:on_spec)
    #   foo.status # => true
    #
    # See ActiveModel::Observing::ClassMethods.notify_observers for more
    # information.
    def notify_observers(method, *extra_args)
      self.class.notify_observers(method, self, *extra_args)
    end
  end

  # == Active Model Observers
  #
  # Observer classes respond to life cycle callbacks to implement trigger-like
  # behavior outside the original class. This is a great way to reduce the
  # clutter that normally comes when the model class is burdened with
  # functionality that doesn't pertain to the core responsibility of the
  # class.
  #
  #   class CommentObserver < ActiveModel::Observer
  #     def after_save(comment)
  #       Notifications.comment('admin@do.com', 'New comment was posted', comment).deliver
  #     end
  #   end
  #
  # This Observer sends an email when a <tt>Comment#save</tt> is finished.
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
  # name. So <tt>CommentObserver</tt> will be tied to observing <tt>Comment</tt>,
  # <tt>ProductManagerObserver</tt> to <tt>ProductManager</tt>, and so on. If
  # you want to name your observer differently than the class you're interested
  # in observing, you can use the <tt>Observer.observe</tt> class method which
  # takes either the concrete class (<tt>Product</tt>) or a symbol for that
  # class (<tt>:product</tt>):
  #
  #   class AuditObserver < ActiveModel::Observer
  #     observe :account
  #
  #     def after_update(account)
  #       AuditTrail.new(account, 'UPDATED')
  #     end
  #   end
  #
  # If the audit observer needs to watch more than one kind of object, this can
  # be specified with multiple arguments:
  #
  #   class AuditObserver < ActiveModel::Observer
  #     observe :account, :balance
  #
  #     def after_update(record)
  #       AuditTrail.new(record, 'UPDATED')
  #     end
  #   end
  #
  # The <tt>AuditObserver</tt> will now act on both updates to <tt>Account</tt>
  # and <tt>Balance</tt> by treating them both as records.
  #
  # If you're using an Observer in a Rails application with Active Record, be
  # sure to read about the necessary configuration in the documentation for
  # ActiveRecord::Observer.
  class Observer
    include Singleton
    extend ActiveSupport::DescendantsTracker

    class << self
      # Attaches the observer to the supplied model classes.
      #
      #   class AuditObserver < ActiveModel::Observer
      #     observe :account, :balance
      #   end
      #
      #   AuditObserver.observed_classes # => [Account, Balance]
      def observe(*models)
        models.flatten!
        models.collect! { |model| model.respond_to?(:to_sym) ? model.to_s.camelize.constantize : model }
        singleton_class.redefine_method(:observed_classes) { models }
      end

      # Returns an array of Classes to observe.
      #
      #   AccountObserver.observed_classes # => [Account]
      #
      # You can override this instead of using the +observe+ helper.
      #
      #   class AuditObserver < ActiveModel::Observer
      #     def self.observed_classes
      #       [Account, Balance]
      #     end
      #   end
      def observed_classes
        Array(observed_class)
      end

      # Returns the class observed by default. It's inferred from the observer's
      # class name.
      #
      #   PersonObserver.observed_class  # => Person
      #   AccountObserver.observed_class # => Account
      def observed_class
        name[/(.*)Observer/, 1].try :constantize
      end
    end

    # Start observing the declared classes and their subclasses.
    # Called automatically by the instance method.
    def initialize #:nodoc:
      observed_classes.each { |klass| add_observer!(klass) }
    end

    def observed_classes #:nodoc:
      self.class.observed_classes
    end

    # Send observed_method(object) if the method exists and
    # the observer is enabled for the given object's class.
    def update(observed_method, object, *extra_args, &block) #:nodoc:
      return if !respond_to?(observed_method) || disabled_for?(object)
      send(observed_method, object, *extra_args, &block)
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

      # Returns true if notifications are disabled for this object.
      def disabled_for?(object) #:nodoc:
        klass = object.class
        return false unless klass.respond_to?(:observers)
        klass.observers.disabled_for?(self)
      end
  end
end
