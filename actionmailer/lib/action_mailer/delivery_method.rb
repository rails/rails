require "active_support/core_ext/class"
module ActionMailer
  module DeliveryMethod

    autoload :File,     'action_mailer/delivery_method/file'
    autoload :Sendmail, 'action_mailer/delivery_method/sendmail'
    autoload :Smtp,     'action_mailer/delivery_method/smtp'
    autoload :Test,     'action_mailer/delivery_method/test'

    # Creates a new DeliveryMethod object according to the given options.
    #
    # If no arguments are passed to this method, then a new
    # ActionMailer::DeliveryMethod::Stmp object will be returned.
    #
    # If you pass a Symbol as the first argument, then a corresponding
    # delivery method class under the ActionMailer::DeliveryMethod namespace
    # will be created.
    # For example:
    #
    #   ActionMailer::DeliveryMethod.lookup_method(:sendmail)
    #   # => returns a new ActionMailer::DeliveryMethod::Sendmail object
    #
    # If the first argument is not a Symbol, then it will simply be returned:
    #
    #   ActionMailer::DeliveryMethod.lookup_method(MyOwnDeliveryMethod.new)
    #   # => returns MyOwnDeliveryMethod.new
    def self.lookup_method(delivery_method)
      case delivery_method
      when Symbol
        method_name  = delivery_method.to_s.camelize
        method_class = ActionMailer::DeliveryMethod.const_get(method_name)
        method_class.new
      when nil # default
        Smtp.new
      else
        delivery_method
      end
    end

    # An abstract delivery method class. There are multiple delivery method classes.
    # See the classes under the ActionMailer::DeliveryMethod, e.g.
    # ActionMailer::DeliveryMethod::Smtp.
    # Smtp is the default delivery method for production
    # while Test is used in testing.
    #
    # each delivery method exposes just one method
    #
    #   delivery_method = ActionMailer::DeliveryMethod::Smtp.new
    #   delivery_method.perform_delivery(mail) # send the mail via smtp
    #
    class Method
      superclass_delegating_accessor :settings
      self.settings = {}
    end
    
  end
end
