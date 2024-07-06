# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  class LogSubscriber < ActiveSupport::LogSubscriber
    class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

    def redirect(event)
      payload = event.payload

      info { "Redirected to #{payload[:location]}" }

      info do
        if ActionDispatch.verbose_redirect_logs && (source = redirect_source_location)
          "↳ #{source}"
        end
      end

      info do
        status = payload[:status]

        message = +"Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} in #{event.duration.round}ms"
        message << "\n\n" if defined?(Rails.env) && Rails.env.development?

        message
      end
    end
    subscribe_log_level :redirect, :info

    private
      def redirect_source_location
        backtrace_cleaner.first_clean_frame
      end
  end
end

ActionDispatch::LogSubscriber.attach_to :action_dispatch
