# frozen_string_literal: true

module ActionMailer
  module MailRegister
    extend ActiveSupport::Concern

    module ClassMethods
      mattr_accessor :mailers_observers, instance_writer: false, default: {}
      mattr_accessor :mailers_interceptors, instance_writer: false, default: {}

      # Register one or more Observers which will be notified when mail is delivered.
      def register_observers(*observers)
        observers.flatten.compact.each { |observer| register_observer(observer) }
      end

      # Unregister one or more previously registered Observers.
      def unregister_observers(*observers)
        observers.flatten.compact.each { |observer| unregister_observer(observer) }
      end

      # Register one or more Interceptors which will be called before mail is sent.
      def register_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| register_interceptor(interceptor) }
      end

      # Unregister one or more previously registered Interceptors.
      def unregister_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| unregister_interceptor(interceptor) }
      end

      # Register an Observer which will be notified when mail is delivered.
      # Either a class, string or symbol can be passed in as the Observer.
      # If a string or symbol is passed in it will be camelized and constantized.
      def register_observer(observer)
        (mailers_observers[self] ||= Set.new) << observer_class_for(observer)
        Mail.register_observer(BaseRegister)
      end

      # Unregister a previously registered Observer.
      # Either a class, string or symbol can be passed in as the Observer.
      # If a string or symbol is passed in it will be camelized and constantized.
      def unregister_observer(observer)
        mailers_observers[self]&.delete(observer_class_for(observer))
      end

      # Register an Interceptor which will be called before mail is sent.
      # Either a class, string or symbol can be passed in as the Interceptor.
      # If a string or symbol is passed in it will be camelized and constantized.
      def register_interceptor(interceptor)
        (mailers_interceptors[self] ||= Set.new) << observer_class_for(interceptor)
        Mail.register_interceptor(BaseRegister)
      end

      # Unregister a previously registered Interceptor.
      # Either a class, string or symbol can be passed in as the Interceptor.
      # If a string or symbol is passed in it will be camelized and constantized.
      def unregister_interceptor(interceptor)
        mailers_interceptors[self]&.delete(observer_class_for(interceptor))
      end

      def observer_class_for(value) # :nodoc:
        case value
        when String, Symbol
          value.to_s.camelize.constantize
        else
          value
        end
      end
      private :observer_class_for
    end

    # Class registered has an interceptor and an observer
    # on behalf of all mailers.
    class BaseRegister
      def self.delivered_email(mail)
        Base.mailers_observers.each do |mailer, observers|
          next unless mail.delivery_handler

          if mail.delivery_handler <= mailer
            observers.each { |observer| observer.delivered_email(mail) }
          end
        end
      end

      def self.delivering_email(mail)
        Base.mailers_interceptors.each do |mailer, interceptors|
          next unless mail.delivery_handler

          if mail.delivery_handler <= mailer
            interceptors.each { |interceptor| interceptor.delivering_email(mail) }
          end
        end
      end
    end
  end
end
