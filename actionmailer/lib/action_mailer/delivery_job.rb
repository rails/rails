# frozen_string_literal: true

require 'active_job'

module ActionMailer
  # The <tt>ActionMailer::DeliveryJob</tt> class is used when you
  # want to send emails outside of the request-response cycle.
  #
  # Exceptions are rescued and handled by the mailer class.
  class DeliveryJob < ActiveJob::Base # :nodoc:
    queue_as { ActionMailer::Base.deliver_later_queue_name }

    rescue_from StandardError, with: :handle_exception_with_mailer_class

    before_perform do
      ActiveSupport::Deprecation.warn <<~MSG.squish
        Sending mail with DeliveryJob and Parameterized::DeliveryJob
        is deprecated and will be removed in Rails 6.1.
        Please use MailDeliveryJob instead.
      MSG
    end

    def perform(mailer, mail_method, delivery_method, *args) #:nodoc:
      mailer.constantize.public_send(mail_method, *args).send(delivery_method)
    end
    ruby2_keywords(:perform) if respond_to?(:ruby2_keywords, true)

    private
      # "Deserialize" the mailer class name by hand in case another argument
      # (like a Global ID reference) raised DeserializationError.
      def mailer_class
        if mailer = Array(@serialized_arguments).first || Array(arguments).first
          mailer.constantize
        end
      end

      def handle_exception_with_mailer_class(exception)
        if klass = mailer_class
          klass.handle_exception exception
        else
          raise exception
        end
      end
  end
end
