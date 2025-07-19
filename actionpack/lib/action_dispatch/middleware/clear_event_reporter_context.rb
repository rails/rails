# frozen_string_literal: true

module ActionDispatch
  # Middleware that sets up a callback on rack.response_finished to clear
  # the EventReporter context when the response is finished. This ensures that
  # context is cleared as late as possible in the request lifecycle.
  class ClearEventReporterContext # :nodoc:
    def initialize(app)
      @app = app
    end

    def call(env)
      response = @app.call(env)

      env["rack.response_finished"] ||= []
      env["rack.response_finished"] << -> do
        ActiveSupport.event_reporter.clear_context
      end

      response
    rescue Exception => e
      ActiveSupport.event_reporter.clear_context
      raise e
    end
  end
end
