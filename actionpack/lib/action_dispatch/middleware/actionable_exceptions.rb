# frozen_string_literal: true

# :markup: markdown

require "uri"
require "active_support/actionable_error"

module ActionDispatch
  class ActionableExceptions # :nodoc:
    cattr_accessor :endpoint, default: "/rails/actions"

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return @app.call(env) unless actionable_request?(request)

      ActiveSupport::ActionableError.dispatch(request.params[:error].to_s.safe_constantize, request.params[:action])

      redirect_to request.params[:location]
    end

    private
      def actionable_request?(request)
        request.get_header("action_dispatch.show_detailed_exceptions") && request.post? && request.path == endpoint
      end

      def redirect_to(location)
        uri = URI.parse location

        if uri.relative? || uri.scheme == "http" || uri.scheme == "https"
          body = ""
        else
          return [400, { Rack::CONTENT_TYPE => "text/plain; charset=utf-8" }, ["Invalid redirection URI"]]
        end

        [302, {
          Rack::CONTENT_TYPE => "text/html; charset=#{Response.default_charset}",
          Rack::CONTENT_LENGTH => body.bytesize.to_s,
          ActionDispatch::Constants::LOCATION => location,
        }, [body]]
      end
  end
end
