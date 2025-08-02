# frozen_string_literal: true

module ActionDispatch
  # TODO: This should go away if we ship https://github.com/rails/rails/pull/55425
  #
  # Middleware that sets up a callback on rack.response_finished to clear
  # the EventReporter context when the response is finished. This ensures that
  # context is cleared as late as possible in the request lifecycle.
  class ClearEventReporterContext # :nodoc:
    def initialize(app)
      @app = app
    end

    def call(env)
      if response_finished = env["rack.response_finished"]
        response_finished << -> do
          ActiveSupport.event_reporter.clear_context
        end
      end

      response = @app.call(env)

      unless response_finished
        response << ::Rack::BodyProxy.new(response.pop) do
          ActiveSupport.event_reporter.clear_context
        end
      end

      response
    rescue Exception => e
      ActiveSupport.event_reporter.clear_context
      raise e
    end
  end
end
