# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  class LogSubscriber < ActiveSupport::LogSubscriber
    def redirect(event)
      payload = event.payload

      info { "Redirected to #{payload[:location]}" }

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
