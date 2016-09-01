# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionMailer
  # Implements the ActiveSupport::LogSubscriber for logging notifications when
  # email is delivered or received.
  class LogSubscriber < ActiveSupport::LogSubscriber
    # An email was delivered.
    def deliver(event)
      if exception = event.payload[:exception]
        error do
          "#{exception.first} was raised when sending mail to #{recipients(event)} (#{duration_in_ms(event)})"
        end
      else
        info do
          "Sent mail to #{recipients(event)} (#{duration_in_ms(event)})"
        end
      end

      debug { event.payload[:mail] }
    end

    # An email was received.
    def receive(event)
      info { "Received mail (#{duration_in_ms(event)})" }
      debug { event.payload[:mail] }
    end

    # An email was generated.
    def process(event)
      debug do
        mailer = event.payload[:mailer]
        action = event.payload[:action]
        "#{mailer}##{action}: processed outbound mail in #{duration_in_ms(event)}"
      end
    end

    # Use the logger configured for ActionMailer::Base.
    def logger
      ActionMailer::Base.logger
    end

    private
      def recipients(event)
        Array(event.payload[:to]).join(", ")
      end

      def duration_in_ms(event)
        "#{event.duration.round(1)}ms"
      end
  end
end

ActionMailer::LogSubscriber.attach_to :action_mailer
