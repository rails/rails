# frozen_string_literal: true

require "erb"
require "action_dispatch/http/request"
require "active_support/actionable_error"

module ActionDispatch
  class ActionableExceptions # :nodoc:
    cattr_accessor :endpoint, default: "/rails/actions"

    cattr_reader :hooks, default: []

    def self.on(exception, &block)
      raise ArgumentError if block.nil?

      hooks << -> err { block.call(err) if exception === err }
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return @app.call(env) unless actionable_request?(request)

      ActiveSupport::ActionableError.dispatch(request.params[:error].to_s.safe_constantize, request.params[:action])

      redirect_to request.params[:location]
    rescue Exception => err
      hooks.each { |hook| hook.call(err) }
      raise
    end

    private
      def actionable_request?(request)
        request.show_exceptions? && request.post? && request.path == endpoint
      end

      def redirect_to(location)
        body = "<html><body>You are being <a href=\"#{ERB::Util.unwrapped_html_escape(location)}\">redirected</a>.</body></html>"

        [302, {
          "Content-Type" => "text/html; charset=#{Response.default_charset}",
          "Content-Length" => body.bytesize.to_s,
          "Location" => location,
        }, [body]]
      end
  end
end
