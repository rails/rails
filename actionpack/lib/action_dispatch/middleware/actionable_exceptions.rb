# frozen_string_literal: true

require "erb"
require "uri"
require "action_dispatch/http/request"
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
        request.get_header("action_dispatch.show_detailed_exceptions")  && request.post? && request.path == endpoint
      end

      def redirect_to(location)
        uri = URI.parse location

        if uri.relative? || uri.scheme == "http" || uri.scheme == "https"
          body = "<html><body>You are being <a href=\"#{ERB::Util.unwrapped_html_escape(location)}\">redirected</a>.</body></html>"
        else
          return [400, { "Content-Type" => "text/plain" }, ["Invalid redirection URI"]]
        end

        [302, {
          "Content-Type" => "text/html; charset=#{Response.default_charset}",
          "Content-Length" => body.bytesize.to_s,
          "Location" => location,
        }, [body]]
      end
  end
end
