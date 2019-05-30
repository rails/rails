# frozen_string_literal: true

require "erb"
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

      actionable_error = request.params[:error].to_s.safe_constantize
      action = request.params[:action]

      rendering_response(request, actionable_error) do
        ActiveSupport::ActionableError.dispatch(actionable_error, action)
      end
    rescue Exception => error
      ActiveSupport::ActionableError.raise_if_triggered_by(error)
      raise
    end

    private
      def actionable_request?(request)
        request.show_exceptions? && request.post? && request.path == endpoint
      end

      def rendering_response(request, error)
        body = capturing_standard_streams { yield }

        [200, {
          "Content-Type" => "text/plain; charset=#{Response.default_charset}",
          "Content-Length" => body.bytesize.to_s,
        }, [body]]
      end

      def capturing_standard_streams
        capture :stdout do
          capture :stderr do
            yield
          end
        end
      end

      def capture(stream)
        stream = stream.to_s
        captured_stream = Tempfile.new(stream)
        stream_io = eval("$#{stream}")
        origin_stream = stream_io.dup
        stream_io.reopen(captured_stream)

        yield

        stream_io.rewind
        captured_stream.read
      ensure
        captured_stream.close
        captured_stream.unlink
        stream_io.reopen(origin_stream)
      end
  end
end
