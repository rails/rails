require 'singleton'

module ActiveRecord
  module Observing # :nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
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
      def observers=(*observers)
        observers = [ observers ].flatten.each do |observer| 
          observer.is_a?(Symbol) ? 
            observer.to_s.camelize.constantize.instance :
            observer.instance
        end
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
    include Reloadable::Subclasses
    
    # Attaches the observer to the supplied model classes.
    def self.observe(*models)
      define_method(:observed_class) { models }
    end

    def initialize
      observed_classes = [ observed_class ].flatten
      observed_subclasses_class = observed_classes.collect {|c| c.send(:subclasses) }.flatten!
      (observed_classes + observed_subclasses_class).each do |klass| 
        klass.add_observer(self)
        klass.send(:define_method, :after_find) unless klass.respond_to?(:after_find)
      end
    end
  
    def update(callback_method, object) #:nodoc:
      send(callback_method, object) if respond_to?(callback_method)
    end
    
    private
      def observed_class
        if self.class.respond_to? "observed_class"
          self.class.observed_class
        else
          Object.const_get(infer_observed_class_name)
        end
      end
      
      def infer_observed_class_name
        self.class.name.scan(/(.*)Observer/)[0][0]
      end
  end
end
