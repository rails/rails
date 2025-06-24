# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionMailer
  # = Action Mailer \LogSubscriber
  #
  # Implements the ActiveSupport::LogSubscriber for logging notifications when
  # email is delivered or received.
  class LogSubscriber < ActiveSupport::LogSubscriber
    # An email was delivered.
    def deliver(event)
      info do
        if exception = event.payload[:exception_object]
          "Failed delivery of mail #{event.payload[:message_id]} error_class=#{exception.class} error_message=#{exception.message.inspect}"
        elsif event.payload[:perform_deliveries]
          "Delivered mail #{event.payload[:message_id]} (#{event.duration.round(1)}ms)"
        else
          "Skipped delivery of mail #{event.payload[:message_id]} as `perform_deliveries` is false"
        end
      end

      debug { event.payload[:mail] }
    end
    subscribe_log_level :deliver, :debug

    # An email was generated.
    def process(event)
      debug do
        mailer = event.payload[:mailer]
        action = event.payload[:action]
        "#{mailer}##{action}: processed outbound mail in #{event.duration.round(1)}ms"
      end
    end
    subscribe_log_level :process, :debug

    # Use the logger configured for ActionMailer::Base.
    def logger
      ActionMailer::Base.logger
    end
  end
end

ActionMailer::LogSubscriber.attach_to :action_mailer
