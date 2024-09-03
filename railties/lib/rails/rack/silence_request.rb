# frozen_string_literal: true
# :markup: markdown

require "active_support/logger_silence"

module Rails
  module Rack
    # Allows you to silence requests made to a specific path and optionally by a specific remote IP.
    # This is useful for preventing recurring requests like healthchecks from clogging the logging.
    # This middleware is used to do just that against the path /up from localhost in production by default.
    #
    # Example:
    #
    #   config.middleware.insert_before Rails::Rack::Logger,
    #     Rails::Rack::SilenceRequest, remote_ip: "127.0.0.1", path: "/up"
    #
    # Note: This should be set before the Rails::Rack::Logger middleware in order to properly silence the entire request.
    class SilenceRequest
      def initialize(app, path:, remote_ip: nil)
        @app, @path, @remote_ip = app, path, remote_ip
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if due_silencing?(request)
          Rails.logger.silence do
            @app.call(env)
          end
        else
          @app.call(env)
        end
      end

      private
        def due_silencing?(request)
          remote_ip_due_silencing?(request) && path_due_silencing?(request)
        end

        def remote_ip_due_silencing?(request)
          @remote_ip ? request.remote_ip == @remote_ip : true
        end

        def path_due_silencing?(request)
          request.path == @path
        end
    end
  end
end
