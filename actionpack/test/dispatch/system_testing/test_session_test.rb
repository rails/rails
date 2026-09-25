# frozen_string_literal: true

require "abstract_unit"
require "net/http"
require "action_dispatch/system_testing/test_session"

class TestSessionTest < ActiveSupport::TestCase
  FakeApp = lambda do |env|
    if env["PATH_INFO"] == "/boom"
      raise "boom"
    else
      [200, { "content-type" => "text/plain" }, ["ok"]]
    end
  end

  setup do
    @sessions = []
  end

  teardown do
    @sessions.each(&:shutdown)
  end

  test "app_host raises before the session starts" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 4000, app_host: "http://rails-app:4000")

    error = assert_raises(ActionDispatch::SystemTesting::TestSession::ServerNotStartedError) do
      session.app_host
    end

    assert_equal "system test session has not started", error.message
  end

  test "start boots a server with configured settings" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0)

    session.start

    assert_match %r{\Ahttp://127\.0\.0\.1:\d+\z}, session.app_host
    assert_equal "ok", get(session.app_host, "/").body
  end

  test "start is idempotent" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0)

    session.start
    app_host = session.app_host
    session.start

    assert_equal app_host, session.app_host
  end

  test "configure can change settings before the session starts" do
    session = new_session
    port = ActionDispatch::SystemTesting::AvailablePortFinder.new("127.0.0.1").find

    session.configure(host: "127.0.0.1", port: 4000)
    session.configure(host: "127.0.0.1", port: port)
    session.start

    assert_equal "http://127.0.0.1:#{port}", session.app_host
  end

  test "configure accepts the same settings after the session starts" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0, app_host: "http://rails-app:4000")
    session.start

    assert_nothing_raised do
      session.configure(host: "127.0.0.1", port: 0, app_host: "http://rails-app:4000")
    end
  end

  test "configure updates app_host after the session starts" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0, app_host: "http://rails-app:4000")
    session.start

    session.configure(host: "127.0.0.1", port: 0, app_host: "http://remote-browser:4000")

    assert_equal "http://remote-browser:4000", session.app_host
  end

  test "configure rejects different server settings after the session starts" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0)
    session.start
    app_host = session.app_host
    port = URI(app_host).port

    error = assert_raises(ArgumentError) do
      session.configure(host: "127.0.0.1", port: port + 1)
    end

    assert_equal "system test session has already started; configure server host and port before the first test runs", error.message
    assert_equal app_host, session.app_host
  end

  test "shutdown stops the server and allows reconfiguration" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0)
    session.start

    session.shutdown

    assert_not session.started?

    session.configure(host: "127.0.0.1", port: 0)
    session.start

    assert_match %r{\Ahttp://127\.0\.0\.1:\d+\z}, session.app_host
  end

  test "clear_server_errors delegates to the server" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0)
    session.start
    request_error(session)

    error = assert_raises(RuntimeError) do
      session.raise_server_errors
    end
    assert_equal "boom", error.message

    session.clear_server_errors

    assert_nothing_raised do
      session.raise_server_errors
    end
  end

  test "raise_server_errors does nothing before the session starts" do
    session = new_session

    assert_nothing_raised do
      session.raise_server_errors
    end
  end

  test "raise_server_errors raises the first collected error" do
    session = new_session
    session.configure(host: "127.0.0.1", port: 0)
    session.start
    request_error(session)

    error = assert_raises(RuntimeError) do
      session.raise_server_errors
    end

    assert_equal "boom", error.message
  end

  private
    def new_session
      ActionDispatch::SystemTesting::TestSession.new(app: FakeApp).tap do |session|
        @sessions << session
      end
    end

    def get(base_url, path)
      Net::HTTP.get_response(URI("#{base_url}#{path}"))
    end

    def request_error(session)
      get(session.app_host, "/boom")
    rescue EOFError, Errno::ECONNRESET
      # Puma may close the connection after the application raises.
    end
end
