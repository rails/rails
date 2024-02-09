# frozen_string_literal: true

module ActionDispatch
  # = Action Dispatch \ReportErrors
  #
  # This middleware is responsible for reporting exceptions through
  # the Active Support Error Reporter
  class ReportErrors
    def initialize(app, executor)
      @app, @executor = app, executor
    end

    def call(env)
      begin
        @app.call(env)
      rescue => error
        @executor.error_reporter.report(error, handled: false, source: "application.action_dispatch")
        raise
      end
    end
  end
end
