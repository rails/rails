# frozen_string_literal: true

require "action_dispatch/system_testing/test_server"

module ActionDispatch
  module SystemTesting
    class TestSession # :nodoc:
      class ServerNotStartedError < StandardError # :nodoc:
      end

      def initialize(app: nil)
        @app = app
        @server = nil
        @host = nil
        @port = nil
        @app_host = nil
      end

      def configure(host:, port:, app_host: nil)
        if started? && server_configuration_changed?(host, port)
          raise ArgumentError, "system test session has already started; configure server host and port before the first test runs"
        end

        @host = host
        @port = port
        @app_host = app_host

        self
      end

      def start
        return self if started?

        server = TestServer.new(
          app: @app || Rails.application,
          host: @host,
          port: @port,
        )
        server.boot

        @server = server
        self
      end

      def started?
        !!@server
      end

      def app_host
        raise ServerNotStartedError, "system test session has not started" unless started?

        @app_host || @server.base_url
      end

      def clear_server_errors
        @server&.clear_server_errors
      end

      def raise_server_errors
        return unless @server

        errors = @server.collect_server_errors
        raise errors.first if errors.any?
      end

      def shutdown
        server = @server
        @server = nil
        server&.stop

        self
      end

      private
        def server_configuration_changed?(host, port)
          @host != host || @port != port
        end
    end

    TEST_SESSION = TestSession.new

    def self.test_session
      TEST_SESSION
    end
  end
end
