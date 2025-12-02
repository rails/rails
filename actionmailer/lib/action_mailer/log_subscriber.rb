# frozen_string_literal: true

require "active_support/log_subscriber"

module ActionMailer
  class LogSubscriber < ActiveSupport::EventReporter::LogSubscriber # :nodoc:
    self.namespace = "action_mailer"

    # An email was delivered.
    def delivered(event)
      payload = event[:payload]
      info do
        if payload[:exception_class]
          "Failed delivery of mail #{payload[:message_id]} error_class=#{payload[:exception_class]} error_message=#{payload[:exception_message].inspect}"
        elsif payload[:perform_deliveries]
          "Delivered mail #{payload[:message_id]} (#{payload[:duration_ms].round(1)}ms)"
        else
          "Skipped delivery of mail #{payload[:message_id]} as `perform_deliveries` is false"
        end
      end

      debug { payload[:mail] }
    end
    event_log_level :delivered, :debug

    # An email was generated.
    def processed(event)
      debug do
        mailer = event[:payload][:mailer]
        action = event[:payload][:action]
        "#{mailer}##{action}: processed outbound mail in #{event[:payload][:duration_ms].round(1)}ms"
      end
    end
    event_log_level :processed, :debug

    def self.default_logger
      ActionMailer::Base.logger
    end
  end
end

ActiveSupport.event_reporter.subscribe(
  ActionMailer::LogSubscriber.new, &ActionMailer::LogSubscriber.subscription_filter
)
