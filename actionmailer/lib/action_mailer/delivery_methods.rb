require 'tmpdir'

module ActionMailer
  # Provides a DSL for adding delivery methods to ActionMailer.
  module DeliveryMethods
    extend ActiveSupport::Concern

    included do
      extlib_inheritable_accessor :delivery_methods, :delivery_method,
                                  :instance_writer => false

      self.delivery_methods = {}
      self.delivery_method  = :smtp

      add_delivery_method :smtp, Mail::SMTP,
        :address              => "localhost",
        :port                 => 25,
        :domain               => 'localhost.localdomain',
        :user_name            => nil,
        :password             => nil,
        :authentication       => nil,
        :enable_starttls_auto => true

      add_delivery_method :file, Mail::FileDelivery,
        :location => defined?(Rails.root) ? "#{Rails.root}/tmp/mails" : "#{Dir.tmpdir}/mails"

      add_delivery_method :sendmail, Mail::Sendmail,
        :location   => '/usr/sbin/sendmail',
        :arguments  => '-i -t'

      add_delivery_method :test, Mail::TestMailer
    end

    module ClassMethods
      # Adds a new delivery method through the given class using the given symbol
      # as alias and the default options supplied:
      #
      # Example:
      # 
      #   add_delivery_method :sendmail, Mail::Sendmail,
      #     :location   => '/usr/sbin/sendmail',
      #     :arguments  => '-i -t'
      # 
      def add_delivery_method(symbol, klass, default_options={})
        unless respond_to?(:"#{symbol}_settings")
          extlib_inheritable_accessor(:"#{symbol}_settings", :instance_writer => false)
        end

        send(:"#{symbol}_settings=", default_options)
        self.delivery_methods[symbol.to_sym] = klass
      end

      def wrap_delivery_behavior(mail, method=delivery_method) #:nodoc:
        mail.register_for_delivery_notification(self)

        if method.is_a?(Symbol)
          if klass = delivery_methods[method.to_sym]
            mail.delivery_method(klass, send(:"#{method}_settings"))
          else
            raise "Invalid delivery method #{method.inspect}"
          end
        else
          mail.delivery_method(method)
        end

        mail.perform_deliveries    = perform_deliveries
        mail.raise_delivery_errors = raise_delivery_errors
      end
    end

    def wrap_delivery_behavior!(*args) #:nodoc:
      self.class.wrap_delivery_behavior(message, *args)
    end
  end
end