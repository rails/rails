# frozen_string_literal: true

# :markup: markdown

require "rack/body_proxy"

module ActionDispatch
  class Executor
    def initialize(app, executor)
      @app, @executor = app, executor
    end

    def call(env)
      state = @executor.run!(reset: true)

      completed = false
      finalize = -> {
        next if completed
        completed = true
        state.complete!
      }

      if response_finished = env["rack.response_finished"]
        response_finished << proc { finalize.call }
      end

      begin
        response = @app.call(env)

        if env["action_dispatch.report_exception"]
          error = env["action_dispatch.exception"]
          @executor.error_reporter.report(error, handled: false, source: "application.action_dispatch")
        end

        if hijacked?(env, response)
          # `close` and `rack.response_finished` may never fire on hijack.
          # Release eagerly; the request's autoloaded code is resolved by now.
          finalize.call
        elsif !response_finished
          response << ::Rack::BodyProxy.new(response.pop) { finalize.call }
        end
        returned = true
        response
      rescue Exception => error
        request = ActionDispatch::Request.new env
        backtrace_cleaner = request.get_header("action_dispatch.backtrace_cleaner")
        wrapper = ExceptionWrapper.new(backtrace_cleaner, error)
        @executor.error_reporter.report(wrapper.unwrapped_exception, handled: false, source: "application.action_dispatch")
        raise
      ensure
        if !returned && !response_finished
          finalize.call
        end
      end
    end

    private
      def hijacked?(env, response)
        return false unless response

        env["rack.hijack_io"] || response.first == 101
      end
  end
end
