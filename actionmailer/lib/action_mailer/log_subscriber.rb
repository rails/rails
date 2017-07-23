# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionMailer
  # Implements the ActiveSupport::LogSubscriber for logging notifications when
  # email is delivered or received.
  class LogSubscriber < ActiveSupport::LogSubscriber
    # An email was delivered.
    def deliver(event)
      info do
        recipients = Array(event.payload[:to]).join(", ")
        "Sent mail to #{recipients} (#{event.duration.round(1)}ms)"
      end

      debug { event.payload[:mail] }
    end

    # An email was received.
    def receive(event)
      info { "Received mail (#{event.duration.round(1)}ms)" }
      debug { event.payload[:mail] }
    end

    # An email was generated.
    def process(event)
      debug do
        mailer = event.payload[:mailer]
        action = event.payload[:action]
        "#{mailer}##{action}: processed outbound mail in #{event.duration.round(1)}ms"
      end
    end

    # Use the logger configured for ActionMailer::Base.
    def logger
      ActionMailer::Base.logger
    end
  end
end

ActionMailer::LogSubscriber.attach_to :action_mailer
