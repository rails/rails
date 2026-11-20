# frozen_string_literal: true

require "net/http"

module ActionDispatch
  module SystemTesting
    class ReadinessChecker # :nodoc:
      class Middleware # :nodoc:
        PATH = "/__object_id__"

        def initialize(app)
          @app = app
          @object_id = app.object_id.to_s
        end

        def call(env)
          if env["REQUEST_METHOD"] == "GET" && env["PATH_INFO"] == PATH
            [200, { "Content-Type" => "text/plain" }, [@object_id]]
          else
            @app.call(env)
          end
        end
      end

      class TimeoutError < StandardError # :nodoc:
      end

      def initialize(app, host, port)
        @object_id = app.object_id.to_s
        @host = host
        @port = port
      end

      def responsive?
        response = Net::HTTP.start(@host, @port, read_timeout: 2, max_retries: 0) do |http|
          http.get(Middleware::PATH)
        end

        response.is_a?(Net::HTTPSuccess) && response.body == @object_id
      rescue EOFError, SystemCallError, Net::ReadTimeout
        false
      end

      def wait_for_responsive(timeout:)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        until responsive?
          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= start_time + timeout
            raise TimeoutError.new("Rack application timed out during boot")
          end

          sleep 0.01
        end
      end
    end
  end
end
