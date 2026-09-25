# frozen_string_literal: true

require "abstract_unit"
require "socket"
require "timeout"
require "action_dispatch/system_testing/available_port_finder"
require "action_dispatch/system_testing/readiness_checker"

class ReadinessCheckerTest < ActiveSupport::TestCase
  class BaseHttpServer
    attr_reader :port

    def initialize(port: 0)
      @mutex = Mutex.new
      @connection_count = 0
      @server = TCPServer.new("127.0.0.1", port)
      @port = @server.addr[1]
      @thread = Thread.new do
        Thread.current.report_on_exception = false
        handle_requests
      end
    end

    def self.start(**options)
      server = new(**options)
      begin
        yield server
      ensure
        server.stop
      end
    end

    def connection_count
      @mutex.synchronize { @connection_count }
    end

    def request_method
      @mutex.synchronize { @request_method }
    end

    def request_path
      @mutex.synchronize { @request_path }
    end

    def stop
      close_server
    ensure
      @thread.kill
      begin
        @thread.join
      rescue StandardError
      end
    end

    def wait
      @thread.join
    end

    private
      def handle_requests
        socket = nil

        loop do
          socket = @server.accept
          record_connection
          handle_socket(socket)
          socket.close
          socket = nil
        end
      rescue IOError, Errno::EBADF
      ensure
        socket&.close
        close_server
      end

      def handle_socket(socket)
        raise NotImplementedError
      end

      def close_server
        @server.close unless @server.closed?
      rescue IOError, Errno::EBADF
      end

      def record_connection
        @mutex.synchronize { @connection_count += 1 }
      end

      def read_request_line(socket)
        request_line = socket.gets
        return unless request_line

        request_method, request_path, = request_line.split
        @mutex.synchronize do
          @request_method = request_method
          @request_path = request_path
        end

        request_line
      end
  end

  class SingleRequestServer < BaseHttpServer
    def initialize(port: 0, body:)
      @body = body
      super(port: port)
    end

    private
      def handle_socket(socket)
        return unless read_request_line(socket)

        socket.write(<<~HTTP)
          HTTP/1.1 200 OK\r
          Content-Type: text/plain\r
          Content-Length: #{@body.bytesize}\r
          Connection: close\r
          \r
        HTTP

        socket.write(@body)

        close_server
      end
  end

  class ClosingServer < BaseHttpServer
    private
      def handle_socket(_socket)
        close_server
      end
  end

  class HangingServer < BaseHttpServer
    private
      def handle_socket(socket)
        read_request_line(socket)
        sleep
      end
  end

  test "responsive when object id endpoint responds with app object id" do
    app = ->(_env) { [200, {}, []] }
    SingleRequestServer.start(body: app.object_id.to_s) do |server|
      checker = ActionDispatch::SystemTesting::ReadinessChecker.new(app, "127.0.0.1", server.port)

      assert checker.responsive?
      assert_equal "GET", server.request_method
      assert_equal "/__object_id__", server.request_path
    end
  end

  test "not responsive when object id endpoint responds with a different object id" do
    app = ->(_env) { [200, {}, []] }
    SingleRequestServer.start(body: "another-app") do |server|
      checker = ActionDispatch::SystemTesting::ReadinessChecker.new(app, "127.0.0.1", server.port)

      assert_not checker.responsive?
    end
  end

  test "not responsive when the endpoint cannot be reached" do
    app = ->(_env) { [200, {}, []] }
    port = ActionDispatch::SystemTesting::AvailablePortFinder.new("127.0.0.1").find
    checker = ActionDispatch::SystemTesting::ReadinessChecker.new(app, "127.0.0.1", port)

    assert_not checker.responsive?
  end

  test "responsive does not retry dropped HTTP connections" do
    app = ->(_env) { [200, {}, []] }
    ClosingServer.start do |server|
      checker = ActionDispatch::SystemTesting::ReadinessChecker.new(app, "127.0.0.1", server.port)

      assert_not checker.responsive?
      assert_equal 1, server.connection_count
    end
  end

  test "responsive times out when HTTP server accepts but does not respond" do
    app = ->(_env) { [200, {}, []] }
    HangingServer.start do |server|
      checker = ActionDispatch::SystemTesting::ReadinessChecker.new(app, "127.0.0.1", server.port)

      Timeout.timeout(5) do
        assert_not checker.responsive?
      end
    end
  end

  test "wait for responsive returns when endpoint becomes responsive" do
    app = ->(_env) { [200, {}, []] }
    port = ActionDispatch::SystemTesting::AvailablePortFinder.new("127.0.0.1").find
    checker = ActionDispatch::SystemTesting::ReadinessChecker.new(app, "127.0.0.1", port)
    server = nil
    server_thread = Thread.new do
      Thread.current.report_on_exception = false
      sleep 0.01
      server = SingleRequestServer.new(port: port, body: app.object_id.to_s)
    end

    assert_nil checker.wait_for_responsive(timeout: 5)
  ensure
    server&.stop
    server_thread&.kill
    server_thread&.join
  end

  test "wait for responsive raises when timeout expires" do
    app = ->(_env) { [200, {}, []] }
    port = ActionDispatch::SystemTesting::AvailablePortFinder.new("127.0.0.1").find
    checker = ActionDispatch::SystemTesting::ReadinessChecker.new(app, "127.0.0.1", port)

    error = assert_raises(ActionDispatch::SystemTesting::ReadinessChecker::TimeoutError) do
      checker.wait_for_responsive(timeout: 0)
    end

    assert_equal "Rack application timed out during boot", error.message
  end
end
