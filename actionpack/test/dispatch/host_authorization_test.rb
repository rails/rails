# frozen_string_literal: true

require "abstract_unit"
require "ipaddr"

class HostAuthorizationTest < ActionDispatch::IntegrationTest
  App = -> env { [200, {}, %w(Success)] }

  test "blocks requests to unallowed host with empty body" do
    @app = ActionDispatch::HostAuthorization.new(App, %w(only.com))

    get "/"

    assert_response :forbidden
    assert_empty response.body
  end

  test "renders debug info when all requests considered as local" do
    @app = ActionDispatch::HostAuthorization.new(App, %w(only.com))

    get "/", env: { "action_dispatch.show_detailed_exceptions" => true }

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

  test "hosts are matched case insensitive" do
    @app = ActionDispatch::HostAuthorization.new(App, "Example.local")

    get "/", env: {
      "HOST" => "example.local",
    }

    assert_response :ok
    assert_equal "Success", body
  end

  test "hosts are matched case insensitive with titlecased host" do
    @app = ActionDispatch::HostAuthorization.new(App, "example.local")

    get "/", env: {
      "HOST" => "Example.local",
    }

    assert_response :ok
    assert_equal "Success", body
  end

  test "hosts are matched case insensitive with hosts array" do
    @app = ActionDispatch::HostAuthorization.new(App, ["Example.local"])

    get "/", env: {
      "HOST" => "example.local",
    }

    assert_response :ok
    assert_equal "Success", body
  end

  test "regex matches are not title cased" do
    @app = ActionDispatch::HostAuthorization.new(App, [/www.Example.local/])

    get "/", env: {
      "HOST" => "www.example.local",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: www.example.local", response.body
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
      "action_dispatch.show_detailed_exceptions" => true
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

  test "mark the host when authorized" do
    @app = ActionDispatch::HostAuthorization.new(App, ".example.com")

    get "/"

    assert_equal "www.example.com", request.get_header("action_dispatch.authorized_host")
  end

  test "sanitizes regular expressions to prevent accidental matches" do
    @app = ActionDispatch::HostAuthorization.new(App, [/w.example.co/])

    get "/", env: { "action_dispatch.show_detailed_exceptions" => true }

    assert_response :forbidden
    assert_match "Blocked host: www.example.com", response.body
  end

  test "blocks requests to unallowed host supporting custom responses" do
    @app = ActionDispatch::HostAuthorization.new(App, ["w.example.co"], response_app: -> env do
      [401, {}, %w(Custom)]
    end)

    get "/"

    assert_response :unauthorized
    assert_equal "Custom", body
  end

  test "localhost works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "localhost:3000",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV4 works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "127.0.0.1",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV4 with port works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "127.0.0.1:3000",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV4 binding in all addresses works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "0.0.0.0",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV4 with port binding in all addresses works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "0.0.0.0:3000",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV6 works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "::1",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV6 with port works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "[::1]:3000",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV6 binding in all addresses works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "::",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "localhost using IPV6 with port binding in all addresses works in dev" do
    @app = ActionDispatch::HostAuthorization.new(App, ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT)

    get "/", env: {
      "HOST" => "[::]:3000",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "hosts with port works" do
    @app = ActionDispatch::HostAuthorization.new(App, ["host.test"])

    get "/", env: {
      "HOST" => "host.test:3000",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :ok
    assert_match "Success", response.body
  end

  test "blocks requests with spoofed X-FORWARDED-HOST" do
    @app = ActionDispatch::HostAuthorization.new(App, [IPAddr.new("127.0.0.1")])

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "127.0.0.1",
      "HOST" => "www.example.com",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: 127.0.0.1", response.body
  end

  test "blocks requests with spoofed relative X-FORWARDED-HOST" do
    @app = ActionDispatch::HostAuthorization.new(App, ["www.example.com"])

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "//randomhost.com",
      "HOST" => "www.example.com",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: //randomhost.com", response.body
  end

  test "forwarded secondary hosts are allowed when permitted" do
    @app = ActionDispatch::HostAuthorization.new(App, ".domain.com")

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "example.com, my-sub.domain.com",
      "HOST" => "domain.com",
    }

    assert_response :ok
    assert_equal "Success", body
  end

  test "forwarded secondary hosts are blocked when mismatch" do
    @app = ActionDispatch::HostAuthorization.new(App, "domain.com")

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "domain.com, evil.com",
      "HOST" => "domain.com",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: evil.com", response.body
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
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: localhost", response.body
  end

  test "forwarded hosts should be permitted" do
    @app = ActionDispatch::HostAuthorization.new(App, "domain.com")

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "sub.domain.com",
      "HOST" => "domain.com",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: sub.domain.com", response.body
  end

  test "sub-sub domains should not be permitted" do
    @app = ActionDispatch::HostAuthorization.new(App, ".domain.com")

    get "/", env: {
      "HOST" => "secondary.sub.domain.com",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: secondary.sub.domain.com", response.body
  end

  test "forwarded hosts are allowed when permitted" do
    @app = ActionDispatch::HostAuthorization.new(App, ".domain.com")

    get "/", env: {
      "HTTP_X_FORWARDED_HOST" => "my-sub.domain.com",
      "HOST" => "domain.com",
    }

    assert_response :ok
    assert_equal "Success", body
  end

  test "lots of NG hosts" do
    ng_hosts = [
      "hacker%E3%80%82com",
      "hacker%00.com",
      "www.theirsite.com@yoursite.com",
      "hacker.com/test/",
      "hacker%252ecom",
      ".hacker.com",
      "/\/\/hacker.com/",
      "/hacker.com",
      "../hacker.com",
      ".hacker.com",
      "@hacker.com",
      "hacker.com",
      "hacker.com%23@example.com",
      "hacker.com/.jpg",
      "hacker.com\texample.com/",
      "hacker.com/example.com",
      "hacker.com\@example.com",
      "hacker.com/example.com",
      "hacker.com/"
    ]

    @app = ActionDispatch::HostAuthorization.new(App, "example.com")

    ng_hosts.each do |host|
      get "/", env: {
        "HTTP_X_FORWARDED_HOST" => host,
        "HOST" => "example.com",
        "action_dispatch.show_detailed_exceptions" => true
      }

      assert_response :forbidden
      assert_match "Blocked host: #{host}", response.body
    end
  end

  test "exclude matches allow any host" do
    @app = ActionDispatch::HostAuthorization.new(App, "only.com", exclude: ->(req) { req.path == "/foo" })

    get "/foo"

    assert_response :ok
    assert_equal "Success", body
  end

  test "exclude misses block unallowed hosts" do
    @app = ActionDispatch::HostAuthorization.new(App, "only.com", exclude: ->(req) { req.path == "/bar" })

    get "/foo", env: { "action_dispatch.show_detailed_exceptions" => true }

    assert_response :forbidden
    assert_match "Blocked host: www.example.com", response.body
  end

  test "blocks requests with invalid hostnames" do
    @app = ActionDispatch::HostAuthorization.new(App, ".example.com")

    get "/", env: {
      "HOST" => "attacker.com#x.example.com",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: attacker.com#x.example.com", response.body
  end

  test "blocks requests to similar host" do
    @app = ActionDispatch::HostAuthorization.new(App, "sub.example.com")

    get "/", env: {
      "HOST" => "sub-example.com",
      "action_dispatch.show_detailed_exceptions" => true
    }

    assert_response :forbidden
    assert_match "Blocked host: sub-example.com", response.body
  end

  test "uses logger from the env" do
    @app = ActionDispatch::HostAuthorization.new(App, %w(only.com))
    output = StringIO.new

    get "/", env: { "action_dispatch.logger" => Logger.new(output) }

    assert_response :forbidden
    assert_match "Blocked host: www.example.com", output.rewind && output.read
  end

  test "uses ActionView::Base logger when no logger in the env" do
    @app = ActionDispatch::HostAuthorization.new(App, %w(only.com))
    output = StringIO.new
    logger = Logger.new(output)

    _old, ActionView::Base.logger = ActionView::Base.logger, logger
    begin
      get "/"
    ensure
      ActionView::Base.logger = _old
    end

    assert_response :forbidden
    assert_match "Blocked host: www.example.com", output.rewind && output.read
  end
end
