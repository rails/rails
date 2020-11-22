# frozen_string_literal: true

require "action_dispatch/http/request"

module ActionDispatch
  # This middleware is responsible for instrumenting the request
  class Instrumentation
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      instrumenter = ActiveSupport::Notifications.instrumenter
      instrumenter.start("request.action_dispatch", request: request)

      status, headers, body = @app.call(env)
      body = ::Rack::BodyProxy.new(body) { finish(request) }
      [status, headers, body]
    rescue Exception
      finish(request)
      raise
    end

    private
      def finish(request)
        instrumenter = ActiveSupport::Notifications.instrumenter
        instrumenter.finish("request.action_dispatch", request: request)
      end
  end
end
