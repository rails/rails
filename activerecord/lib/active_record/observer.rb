require 'singleton'

module ActiveRecord
  # Observers can be programmed to react to lifecycle callbacks in another class to implement
  # trigger-like behavior outside the original class. This is a great way to reduce the clutter that
  # normally comes when the model class is burdened with excess responsibility that doesn't pertain to
  # the core and nature of the class. Example:
  #
  #   class CommentObserver < ActiveRecord::Observer
  #     def after_save(comment)
  #       Notifications.deliver_comment("admin@do.com", "New comment was posted", comment)
  #     end
  #   end
  #
  # This Observer is triggered when a Comment#save is finished and sends a notification about it to the administrator.
  #
  # == Observing a class that can't be infered
  #
  # Observers will by default be mapped to the class with which they share a name. So CommentObserver will
  # be tied to observing Comment, ProductManagerObserver to ProductManager, and so on. If you want to name your observer
  # something else than the class you're interested in observing, you can implement the observed_class class method. Like this:
  #
  #   class AuditObserver < ActiveRecord::Observer
  #     def self.observed_class() Account end
  #     def after_update(account)
  #       AuditTrail.new(account, "UPDATED")
  #     end
  #   end
  #
  # == Observing multiple classes at once
  #
  # If the audit observer needs to watch more than one kind of object, this can be specified in an array, like this:
  #
  #   class AuditObserver < ActiveRecord::Observer
  #     def self.observed_class() [ Account, Balance ] end
  #     def after_update(record)
  #       AuditTrail.new(record, "UPDATED")
  #     end
  #   end
  #
  # The AuditObserver will now act on both updates to Account and Balance by treating them both as records.
  #
  # The observer can implement callback methods for each of the methods described in the Callbacks module.
  class Observer
    include Singleton
  
    def initialize
      [ observed_class ].flatten.each do |klass| 
        klass.add_observer(self)
        klass.send(:define_method, :after_find) unless klass.respond_to?(:after_find)
      end
    end
  
    def update(callback_method, object)
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