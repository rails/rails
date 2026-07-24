# frozen_string_literal: true

require "abstract_unit"
require "net/http"
require "puma"
require "timeout"
require "action_dispatch/system_testing/test_server"

class TestServerTest < ActiveSupport::TestCase
  def app
    @app ||= lambda do |env|
      case env["PATH_INFO"]
      when "/"
        [200, { "content-type" => "text/plain" }, ["Hello from TestServer"]]
      else
        [404, { "content-type" => "text/plain" }, ["Not Found"]]
      end
    end
  end

  def get(server, path)
    Net::HTTP.get(URI("#{server.base_url}#{path}"))
  end

  test "requires a rack app" do
    assert_raises(ArgumentError) do
      ActionDispatch::SystemTesting::TestServer.new
    end
  end

  test "defaults host and finds an available port" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app)
    uri = URI(server.base_url)

    assert_equal "127.0.0.1", uri.host
    assert_kind_of Integer, uri.port
  end

  test "normalizes the 0.0.0.0 bind host to 127.0.0.1 in base_url" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "0.0.0.0", port: 4567)

    assert_equal "http://127.0.0.1:4567", server.base_url
  end

  test "treats port 0 as a request for an available port" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1", port: 0)
    uri = URI(server.base_url)

    assert_kind_of Integer, uri.port
    assert_not_equal 0, uri.port
  end

  test "uses numeric string ports" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1", port: "4567")

    assert_equal "http://127.0.0.1:4567", server.base_url
  end

  test "builds base_url for IPv6 hosts" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "::1", port: 4567)

    assert_equal "http://[::1]:4567", server.base_url
  end

  test "raises ArgumentError for invalid ports" do
    error1 = assert_raises(ArgumentError) do
      ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1", port: -1)
    end
    error2 = assert_raises(ArgumentError) do
      ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1", port: 65536)
    end
    error3 = assert_raises(ArgumentError) do
      ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1", port: "not-a-port")
    end

    assert_equal "port must be in the range 0..65535", error1.message
    assert_equal "port must be in the range 0..65535", error2.message
    assert_equal "port must be in the range 0..65535", error3.message
  end

  test "boot starts a puma server that serves the rack app and object id endpoint" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1")
    server.boot

    assert_match %r{\Ahttp://127\.0\.0\.1:\d+\z}, server.base_url
    assert_equal "Hello from TestServer", get(server, "/")
    assert_equal app.object_id.to_s, get(server, "/__object_id__")
  ensure
    server&.stop
  end

  test "loads the puma rack handler" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1")

    assert_respond_to server.send(:rack_handler_puma), :config
  end

  test "server errors are collected and cleared in the test process" do
    app = lambda do |env|
      if env["PATH_INFO"] == "/boom"
        raise "boom"
      else
        [200, { "content-type" => "text/plain" }, ["ok"]]
      end
    end
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1")
    server.boot

    begin
      get(server, "/boom")
    rescue EOFError, Errno::ECONNRESET
      # Puma may close the connection after the application raises.
    end

    errors = server.collect_server_errors
    assert_equal 1, errors.size
    error = errors.first
    assert_equal "boom", error.message

    server.clear_server_errors
    assert_empty server.collect_server_errors
  ensure
    server&.stop
  end

  test "boot raises when the configured port is already in use" do
    host = "127.0.0.1"
    blocker = TCPServer.new(host, 0)
    port = blocker.addr[1]
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: host, port: port)

    assert_raises(Errno::EADDRINUSE) do
      server.boot
    end
  ensure
    server&.stop
    blocker&.close
  end

  test "stop shuts down the puma server" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1")
    server.boot

    server.stop

    assert_raises(Errno::ECONNREFUSED) do
      get(server, "/")
    end
  ensure
    server&.stop
  end

  test "stop shuts down gracefully" do
    request_started = Queue.new
    finish_request = Queue.new
    app = lambda do |env|
      if env["PATH_INFO"] == "/slow"
        request_started << true
        finish_request.pop
        [200, { "content-type" => "text/plain" }, ["finished"]]
      else
        [200, { "content-type" => "text/plain" }, ["ok"]]
      end
    end
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1")
    server.boot

    request_thread = Thread.new { get(server, "/slow") }
    Timeout.timeout(5) { request_started.pop }

    stop_thread = Thread.new { server.stop }
    assert_nil stop_thread.join(0.1), "expected server.stop to wait for in-flight requests"

    finish_request << true

    assert_equal "finished", Timeout.timeout(5) { request_thread.value }
    Timeout.timeout(5) { stop_thread.value }
  ensure
    finish_request << true if finish_request
    server&.stop
    request_thread&.join(1)
    stop_thread&.join(1)
  end

  test "boot requires puma 5.6.3 or newer" do
    server = ActionDispatch::SystemTesting::TestServer.new(app: app, host: "127.0.0.1")

    old_version = Puma::Const::PUMA_VERSION
    silence_warnings do
      Puma::Const.const_set(:PUMA_VERSION, "5.6.2")
    end

    error = assert_raises(LoadError) do
      server.boot
    end

    assert_equal "Action Dispatch system testing server requires `puma` version 5.6.3 or newer.", error.message
  ensure
    silence_warnings do
      Puma::Const.const_set(:PUMA_VERSION, old_version)
    end
  end
end
