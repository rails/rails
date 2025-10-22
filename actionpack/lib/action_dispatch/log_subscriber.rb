# frozen_string_literal: true

module ActionDispatch
  class LogSubscriber < ActiveSupport::LogSubscriber # :nodoc:
    class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

    def redirect(event)
      payload = event.payload

      info { "Redirected to #{payload[:location]}" }

      if ActionDispatch.verbose_redirect_logs
        info { "↳ #{payload[:source_location]}" }
      end

      info do
        status = payload[:status]

        message = +"Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} in #{event.duration.round}ms"
        message << "\n\n" if defined?(Rails.env) && Rails.env.development?

        message
      end
    end
    subscribe_log_level :redirect, :info
  end
end

ActionDispatch::LogSubscriber.attach_to :action_dispatch
