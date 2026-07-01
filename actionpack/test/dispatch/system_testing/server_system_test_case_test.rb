# frozen_string_literal: true

require "abstract_unit"
require "net/http"
require "action_dispatch/server_system_test_case"

class ServerSystemTestCaseTest < ActiveSupport::TestCase
  FakeApp = lambda do |env|
    if env["PATH_INFO"] == "/boom"
      raise "boom"
    else
      [200, { "content-type" => "text/plain" }, ["ok"]]
    end
  end

  class MyApplicationSystemTestCase < ActionDispatch::ServerSystemTestCase
  end

  def new_test_case
    Class.new(MyApplicationSystemTestCase) do
      def test_something
      end
    end
  end

  test "served_by configures the test session" do
    with_test_session do |session|
      klass = new_test_case
      klass.served_by host: "127.0.0.1", port: 0, app_host: "http://rails-app:4000"

      error = assert_raises(ActionDispatch::SystemTesting::TestSession::ServerNotStartedError) do
        klass.new("test_something").base_url
      end
      assert_equal "system test session has not started", error.message

      session.start

      instance = klass.new("test_something")
      assert_equal "http://rails-app:4000", instance.base_url
      assert_equal "http://rails-app:4000", instance.app_host
    end
  end

  test "before_setup starts the test session" do
    with_test_session do |session|
      klass = new_test_case
      klass.served_by host: "127.0.0.1", port: 0
      instance = klass.new("test_something")

      instance.send(:before_setup)

      assert_match %r{\Ahttp://127\.0\.0\.1:\d+\z}, session.app_host
      assert_equal session.app_host, instance.base_url
      assert_equal session.app_host, instance.app_host
    end
  end

  test "before_setup clears previous server errors" do
    with_test_session do |session|
      klass = new_test_case
      klass.served_by host: "127.0.0.1", port: 0
      session.start
      request_error(session)
      assert_raises(RuntimeError) do
        session.raise_server_errors
      end
      instance = klass.new("test_something")

      instance.send(:before_setup)

      assert_nothing_raised do
        session.raise_server_errors
      end
    end
  end

  test "test session is shared by all test case classes" do
    with_test_session do |session|
      a = new_test_case
      b = new_test_case
      a.served_by host: "127.0.0.1", port: 0
      session.start

      assert_equal session.app_host, b.new("test_something").base_url
    end
  end

  test "served_by raises when changing settings after the test session starts" do
    with_test_session do |session|
      klass = new_test_case
      klass.served_by host: "127.0.0.1", port: 0
      session.start
      app_host = session.app_host

      error = assert_raises(ArgumentError) do
        klass.served_by host: "127.0.0.1", port: 1
      end

      assert_equal "system test session has already started; configure server host and port before the first test runs", error.message
      assert_equal app_host, klass.new("test_something").base_url
    end
  end

  test "url helpers are generated against base_url" do
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      get "/users/new", to: "users#new", as: :new_user
    end

    with_test_session do |session|
      session.configure(host: "127.0.0.1", port: 0, app_host: "http://127.0.0.1:9999")
      session.start

      with_test_app(Struct.new(:routes).new(routes)) do
        instance = new_test_case.new("test_something")

        assert_equal "http://127.0.0.1:9999/users/new", instance.new_user_url
        assert_equal "/users/new", instance.new_user_path
        assert_respond_to instance, :new_user_url
      end
    end
  end

  test "server errors are raised during teardown" do
    with_test_session do |session|
      klass = new_test_case
      klass.served_by host: "127.0.0.1", port: 0
      session.start
      request_error(session)
      instance = klass.new("test_something")
      instance.assert true

      error = assert_raises(RuntimeError) do
        instance.send(:after_teardown)
      end

      assert_equal "boom", error.message
    end
  end

  private
    def with_test_session
      session = ActionDispatch::SystemTesting::TestSession.new(app: FakeApp)
      ActionDispatch::SystemTesting.stub(:test_session, session) do
        yield session
      end
    ensure
      session.shutdown
    end

    def with_test_app(app)
      old = ActionDispatch.test_app
      ActionDispatch.test_app = app
      yield
    ensure
      ActionDispatch.test_app = old
    end

    def request_error(session)
      Net::HTTP.get_response(URI("#{session.app_host}/boom"))
    rescue EOFError, Errno::ECONNRESET
      # Puma may close the connection after the application raises.
    end
end
