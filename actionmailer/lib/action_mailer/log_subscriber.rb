require 'active_support/log_subscriber'

module ActionMailer
  # Implements the ActiveSupport::LogSubscriber for logging notifications when
  # email is delivered and received.
  class LogSubscriber < ActiveSupport::LogSubscriber
    # An email was delivered.
    def deliver(event)
      return unless logger.info?
      recipients = Array(event.payload[:to]).join(', ')
      info("\nSent mail to #{recipients} (#{event.duration.round(1)}ms)")
      debug(event.payload[:mail])
    end

    # An email was received.
    def receive(event)
      return unless logger.info?
      info("\nReceived mail (#{event.duration.round(1)}ms)")
      debug(event.payload[:mail])
    end

    # An email was generated.
    def process(event)
      mailer = event.payload[:mailer]
      action = event.payload[:action]
      debug("\n#{mailer}##{action}: processed outbound mail in #{event.duration.round(1)}ms")
    end

    # Use the logger configured for ActionMailer::Base
    def logger
      ActionMailer::Base.logger
    end
  end
end

ActionMailer::LogSubscriber.attach_to :action_mailer
