# frozen_string_literal: true

require "abstract_unit"
require "ipaddr"

class HostAuthorizationTest < ActionDispatch::IntegrationTest
  App = -> env { [200, {}, %w(Success)] }

  test "blocks requests to unallowed host" do
    @app = ActionDispatch::HostAuthorization.new(App, %w(only.com))

    get "/"

    assert_response :forbidden
    assert_match "Blocked host: www.example.com", response.body
  end

  test "allows all requests if hosts is empty" do
    @app = ActionDispatch::HostAuthorization.new(App, nil)

    get "/"

    assert_response :ok
    assert_equal "Success", body
  end

  test "hosts can be a single element array" do
    @app = ActionDispatch::HostAuthorization.new(App, %w(www.example.com))

    get "/"

    assert_response :ok
    assert_equal "Success", body
  end

  test "hosts can be a string" do
    @app = ActionDispatch::HostAuthorization.new(App, "www.example.com")

    get "/"

    assert_response :ok
    assert_equal "Success", body
  end

  test "passes requests to allowed hosts with domain name notation" do
    @app = ActionDispatch::HostAuthorization.new(App, ".example.com")

    get "/"

    assert_response :ok
    assert_equal "Success", body
  end

  test "does not allow domain name notation in the HOST header itself" do
    @app = ActionDispatch::HostAuthorization.new(App, ".example.com")

    get "/", env: {
      "HOST" => ".example.com",
    }

    assert_response :forbidden
    assert_match "Blocked host: .example.com", response.body
  end

  test "checks for requests with #=== to support wider range of host checks" do
    @app = ActionDispatch::HostAuthorization.new(App, [-> input { input == "www.example.com" }])

    get "/"

    assert_response :ok
    assert_equal "Success", body
  end

  test "proc host can accept both host and request" do
    host_proc = proc { |host, req| host == "example.com" || req.path == "/skip" }
    @app = ActionDispatch::HostAuthorization.new(App, host_proc)

    get "/skip", env: {
      "HOST" => "forbidden",
      "X-Forwarded-Host" => "forbidden"
    }

    assert_response :ok
    assert_equal "Success", body
  end

  test "mark the host when authorized" do
    @app = ActionDispatch::HostAuthorization.new(App, ".example.com")

    get "/"

    assert_equal "www.example.com", request.get_header("action_dispatch.authorized_host")
  end

  test "sanitizes regular expressions to prevent accidental matches" do
    @app = ActionDispatch::HostAuthorization.new(App, [/w.example.co/])

    get "/"

    assert_response :forbidden
    assert_match "Blocked host: www.example.com", response.body
  end

  test "blocks requests to unallowed host supporting custom responses" do
    @app = ActionDispatch::HostAuthorization.new(App, ["w.example.co"], -> env do
      [401, {}, %w(Custom)]
    end)

    get "/"

    assert_response :unauthorized
    assert_equal "Custom", body
  end

  test "blocks requests with spoofed X-FORWARDED-HOST" do
    @app = ActionDispatch::HostAuthorization.new(App, [IPAddr.new("127.0.0.1")])

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "127.0.0.1",
      "HOST" => "www.example.com",
    }

    assert_response :forbidden
    assert_match "Blocked host: 127.0.0.1", response.body
  end

  test "does not consider IP addresses in X-FORWARDED-HOST spoofed when disabled" do
    @app = ActionDispatch::HostAuthorization.new(App, nil)

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "127.0.0.1",
      "HOST" => "www.example.com",
    }

    assert_response :ok
    assert_equal "Success", body
  end

  test "detects localhost domain spoofing" do
    @app = ActionDispatch::HostAuthorization.new(App, "localhost")

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "localhost",
      "HOST" => "www.example.com",
    }

    assert_response :forbidden
    assert_match "Blocked host: localhost", response.body
  end

  test "forwarded hosts should be permitted" do
    @app = ActionDispatch::HostAuthorization.new(App, "domain.com")

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "sub.domain.com",
      "HOST" => "domain.com",
    }

    assert_response :forbidden
    assert_match "Blocked host: sub.domain.com", response.body
  end

  test "forwarded hosts are allowed when permitted" do
    @app = ActionDispatch::HostAuthorization.new(App, ".domain.com")

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "sub.domain.com",
      "HOST" => "domain.com",
    }

    assert_response :ok
    assert_equal "Success", body
  end
end
