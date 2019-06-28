# frozen_string_literal: true

require "erb"
require "action_dispatch/http/request"
require "active_support/actionable_error"
require "active_support/core_ext/numeric/bytes"

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
        body = capture_output { yield }

        [200, {
          "Content-Type" => "text/plain; charset=#{Response.default_charset}",
          "Content-Length" => body.bytesize.to_s,
        }, [body]]
      end

      OUTPUT_CHUNK = 1.megabyte

      def capture_output
        stdout, stderr = $stdout.dup, $stderr.dup

        IO.pipe do |read_io, write_io|
          $stdout.reopen(write_io)
          $stderr.reopen(write_io)

          yield

          write_io.close
          read_io.read_nonblock(OUTPUT_CHUNK)
        end
      rescue IO::WaitReadable
        ""
      ensure
        $stdout.reopen(stdout)
        $stderr.reopen(stderr)
      end
  end
end
