# frozen_string_literal: true

require "uri"
require "action_dispatch/system_testing/available_port_finder"
require "action_dispatch/system_testing/readiness_checker"

module ActionDispatch
  module SystemTesting
    class TestServer # :nodoc:
      BOOT_TIMEOUT = 60
      DEFAULT_OPTIONS = { Threads: "0:4", workers: 0, daemon: false, Silent: true }.freeze
      REQUIRED_PUMA_VERSION = Gem::Requirement.new(">= 5.6.3")

      class ErrorCollecting # :nodoc:
        def initialize(app, reportable_errors: [Exception])
          @app = app
          @reportable_errors = reportable_errors
          @mutex = Mutex.new
          @errors = []
        end

        def call(env)
          @app.call(env)
        rescue *@reportable_errors => error
          @mutex.synchronize { @errors << error }
          raise
        end

        def collect_errors
          @mutex.synchronize do
            return @errors.dup
          end
        end

        def clear_errors
          @mutex.synchronize { @errors.clear }
        end
      end

      def initialize(app:, host: nil, port: nil)
        @host = host || "0.0.0.0"
        @connect_host = @host == "0.0.0.0" ? "127.0.0.1" : @host # `0.0.0.0` is a bind address, not an address clients can connect to.
        @port = detect_or_use(port)

        @checker = ReadinessChecker.new(app, @connect_host, @port)
        @app_with_error_collecting_and_readiness_check = ErrorCollecting.new(ReadinessChecker::Middleware.new(app))
      end

      def boot
        if server_thread_alive? && @checker.responsive?
          return self
        end

        @server = build_server
        @server_thread = @server.run
        begin
          @checker.wait_for_responsive(timeout: BOOT_TIMEOUT)
        rescue ReadinessChecker::TimeoutError
          stop
          raise
        end

        self
      end

      def stop
        @server&.stop(true)
      end

      def base_url
        URI::HTTP.build(host: @connect_host, port: @port).to_s
      end

      def collect_server_errors
        @app_with_error_collecting_and_readiness_check.collect_errors
      end

      def clear_server_errors
        @app_with_error_collecting_and_readiness_check.clear_errors
      end

      private
        def detect_or_use(port)
          port = Integer(port || 0)

          unless port.between?(0, 65_535)
            raise ArgumentError, "port must be in the range 0..65535"
          end

          port.zero? ? AvailablePortFinder.new(@host).find : port
        rescue ArgumentError, TypeError
          raise ArgumentError, "port must be in the range 0..65535"
        end

        def ensure_server_dependencies
          begin
            require "puma"
          rescue LoadError
            raise LoadError, "Unable to load `puma` for Action Dispatch system testing server. Please add `puma` to your project."
          end

          unless REQUIRED_PUMA_VERSION.satisfied_by?(Gem::Version.new(Puma::Const::PUMA_VERSION))
            raise LoadError, "Action Dispatch system testing server requires `puma` version 5.6.3 or newer."
          end

          rack_handler_puma
        end

        def rack_handler_puma
          require "rack/handler/puma"

          # Puma >= 6.1 defines Rackup::Handler::Puma
          # https://github.com/puma/puma/commit/8092bf80852f8881b37003e019e8f64ab9d430b9
          if defined?(Rackup::Handler::Puma)
            Rackup::Handler::Puma
          elsif defined?(Rack::Handler::Puma)
            Rack::Handler::Puma
          else
            raise LoadError, "Unable to load `puma` rack handler for Action Dispatch system testing server."
          end
        end

        def server_thread_alive?
          @server_thread && @server_thread.join(0).nil?
        end

        def with_rack_env_test
          rack_env_defined = ENV.key?("RACK_ENV")
          rack_env = ENV["RACK_ENV"]

          ENV["RACK_ENV"] = "test"
          yield
        ensure
          if rack_env_defined
            ENV["RACK_ENV"] = rack_env
          else
            ENV.delete("RACK_ENV")
          end
        end

        def build_server
          ensure_server_dependencies

          with_rack_env_test do
            config = rack_handler_puma.config(
              @app_with_error_collecting_and_readiness_check,
              DEFAULT_OPTIONS.merge(Host: @host, Port: @port),
            )
            config.clamp
            config.options[:log_writer] = puma_logger(config)

            server = Puma::Server.new(
              config.app,
              nil,
              config.options
            )
            server.binder.parse(config.options[:binds], server.log_writer)

            server
          end
        end

        def puma_logger(config)
          if config.options[:Silent]
            Puma::LogWriter.strings
          else
            Puma::LogWriter.stdio
          end
        end
    end
  end
end
