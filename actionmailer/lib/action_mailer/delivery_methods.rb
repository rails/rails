# frozen_string_literal: true

require 'tmpdir'

module ActionMailer
  # This module handles everything related to mail delivery, from registering
  # new delivery methods to configuring the mail object to be sent.
  module DeliveryMethods
    extend ActiveSupport::Concern

    included do
      # Do not make this inheritable, because we always want it to propagate
      cattr_accessor :raise_delivery_errors, default: true
      cattr_accessor :perform_deliveries, default: true
      cattr_accessor :deliver_later_queue_name, default: :mailers

      class_attribute :delivery_methods, default: {}.freeze
      class_attribute :delivery_method, default: :smtp

      add_delivery_method :smtp, Mail::SMTP,
        address:              'localhost',
        port:                 25,
        domain:               'localhost.localdomain',
        user_name:            nil,
        password:             nil,
        authentication:       nil,
        enable_starttls_auto: true

      add_delivery_method :file, Mail::FileDelivery,
        location: defined?(Rails.root) ? "#{Rails.root}/tmp/mails" : "#{Dir.tmpdir}/mails"

      add_delivery_method :sendmail, Mail::Sendmail,
        location:  '/usr/sbin/sendmail',
        arguments: '-i'

      add_delivery_method :test, Mail::TestMailer
    end

    # Helpers for creating and wrapping delivery behavior, used by DeliveryMethods.
    module ClassMethods
      # Provides a list of emails that have been delivered by Mail::TestMailer
      delegate :deliveries, :deliveries=, to: Mail::TestMailer

      # Adds a new delivery method through the given class using the given
      # symbol as alias and the default options supplied.
      #
      #   add_delivery_method :sendmail, Mail::Sendmail,
      #     location:  '/usr/sbin/sendmail',
      #     arguments: '-i'
      def add_delivery_method(symbol, klass, default_options = {})
        class_attribute(:"#{symbol}_settings") unless respond_to?(:"#{symbol}_settings")
        send(:"#{symbol}_settings=", default_options)
        self.delivery_methods = delivery_methods.merge(symbol.to_sym => klass).freeze
      end

      def wrap_delivery_behavior(mail, method = nil, options = nil) # :nodoc:
        method ||= delivery_method
        mail.delivery_handler = self

        case method
        when NilClass
          raise 'Delivery method cannot be nil'
        when Symbol
          if klass = delivery_methods[method]
            mail.delivery_method(klass, (send(:"#{method}_settings") || {}).merge(options || {}))
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

    def wrap_delivery_behavior!(*args) # :nodoc:
      self.class.wrap_delivery_behavior(message, *args)
    end
  end
end
