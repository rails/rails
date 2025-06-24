# frozen_string_literal: true

require "active_job"

module ActionMailer
  # = Action Mailer \MailDeliveryJob
  #
  # The +ActionMailer::MailDeliveryJob+ class is used when you
  # want to send emails outside of the request-response cycle. It supports
  # sending either parameterized or normal mail.
  #
  # Exceptions are rescued and handled by the mailer class.
  class MailDeliveryJob < ActiveJob::Base # :nodoc:
    queue_as do
      mailer_class = arguments.first.constantize
      mailer_class.deliver_later_queue_name
    end

    rescue_from StandardError, with: :handle_exception_with_mailer_class

    def perform(mailer, mail_method, delivery_method, args:, kwargs: nil, params: nil)
      mailer_class = params ? mailer.constantize.with(params) : mailer.constantize
      message = if kwargs
        mailer_class.public_send(mail_method, *args, **kwargs)
      else
        mailer_class.public_send(mail_method, *args)
      end
      message.send(delivery_method)
    end

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
