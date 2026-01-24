# frozen_string_literal: true

module ActionDispatch
  class LogSubscriber < ActiveSupport::EventReporter::LogSubscriber # :nodoc:
    class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

    self.namespace = "action_dispatch"

    def redirect(event)
      payload = event[:payload]

      info { "Redirected to #{payload[:location]}" }

      if ActionDispatch.verbose_redirect_logs
        info { "↳ #{payload[:source_location]}" }
      end

      info do
        status = payload[:status]
        status_name = payload[:status_name]

        message = +"Completed #{status} #{status_name} in #{payload[:duration_ms].round}ms"
        message << "\n\n" if defined?(Rails.env) && Rails.env.development?

        message
      end
    end
    event_log_level :redirect, :info

    def self.default_logger
      ActionController::Base.logger
    end
  end
end

ActiveSupport.event_reporter.subscribe(
  ActionDispatch::LogSubscriber.new, &ActionDispatch::LogSubscriber.subscription_filter
)
