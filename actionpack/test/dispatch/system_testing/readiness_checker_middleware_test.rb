# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/readiness_checker"

class ReadinessCheckerMiddlewareTest < ActiveSupport::TestCase
  test "GET to object id endpoint returns the app object id" do
    downstream_called = false
    app = lambda do |_env|
      downstream_called = true
      [404, {}, ["downstream"]]
    end
    middleware = ActionDispatch::SystemTesting::ReadinessChecker::Middleware.new(app)

    status, headers, body = middleware.call(Rack::MockRequest.env_for("/__object_id__", method: "GET"))

    assert_equal 200, status
    assert_equal "text/plain", headers["Content-Type"]
    assert_equal app.object_id.to_s, body.join
    assert_not downstream_called
  end

  test "non endpoint requests are delegated to the app" do
    app = lambda do |env|
      [200, {}, [env["PATH_INFO"]]]
    end
    middleware = ActionDispatch::SystemTesting::ReadinessChecker::Middleware.new(app)

    status, _headers, body = middleware.call(Rack::MockRequest.env_for("/posts", method: "GET"))

    assert_equal 200, status
    assert_equal "/posts", body.join
  end

  test "non-GET requests to object id endpoint are delegated to the app" do
    app = lambda do |env|
      [200, {}, [env["REQUEST_METHOD"]]]
    end
    middleware = ActionDispatch::SystemTesting::ReadinessChecker::Middleware.new(app)

    status, _headers, body = middleware.call(Rack::MockRequest.env_for("/__object_id__", method: "OPTIONS"))
    assert_equal 200, status
    assert_equal "OPTIONS", body.join

    status, _headers, body = middleware.call(Rack::MockRequest.env_for("/__object_id__", method: "POST"))
    assert_equal 200, status
    assert_equal "POST", body.join
  end
end
