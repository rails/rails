# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::CrossSiteForgeryTest < ActionCable::TestCase
  HOST = "rubyonrails.com"

  class Connection < ActionCable::Connection::Base
    def send_async(method, *args)
      send method, *args
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
    @server.config.allow_same_origin_as_host = false
  end

  teardown do
    @server.config.disable_request_forgery_protection = false
    @server.config.allowed_request_origins = []
    @server.config.allow_same_origin_as_host = true
  end

  test "disable forgery protection" do
    @server.config.disable_request_forgery_protection = true
    assert_origin_allowed "http://rubyonrails.com"
    assert_origin_allowed "http://hax.com"
  end

  test "explicitly specified a single allowed origin" do
    @server.config.allowed_request_origins = "http://hax.com"
    assert_origin_not_allowed "http://rubyonrails.com"
    assert_origin_allowed "http://hax.com"
  end

  test "explicitly specified multiple allowed origins" do
    @server.config.allowed_request_origins = %w( http://rubyonrails.com http://www.rubyonrails.com )
    assert_origin_allowed "http://rubyonrails.com"
    assert_origin_allowed "http://www.rubyonrails.com"
    assert_origin_not_allowed "http://hax.com"
  end

  test "explicitly specified a single regexp allowed origin" do
    @server.config.allowed_request_origins = /.*ha.*/
    assert_origin_not_allowed "http://rubyonrails.com"
    assert_origin_allowed "http://hax.com"
  end

  test "explicitly specified multiple regexp allowed origins" do
    @server.config.allowed_request_origins = [/http:\/\/ruby.*/, /.*rai.s.*com/, "string" ]
    assert_origin_allowed "http://rubyonrails.com"
    assert_origin_allowed "http://www.rubyonrails.com"
    assert_origin_not_allowed "http://hax.com"
    assert_origin_not_allowed "http://rails.co.uk"
  end

  test "allow same origin as host" do
    @server.config.allow_same_origin_as_host = true
    assert_origin_allowed "http://#{HOST}"
    assert_origin_not_allowed "http://hax.com"
    assert_origin_not_allowed "http://rails.co.uk"
  end

  test "allow same origin with X-Forwarded-Host" do
    @server.config.allow_same_origin_as_host = true
    assert_origin_allowed "http://proxy.example.com", forwarded_host: "proxy.example.com"
    assert_origin_not_allowed "http://hax.com", forwarded_host: "proxy.example.com"
  end

  test "X-Forwarded-Host takes precedence over HTTP_HOST for same origin check" do
    @server.config.allowed_request_origins = []
    @server.config.allow_same_origin_as_host = true
    assert_origin_allowed "http://proxy.example.com", forwarded_host: "proxy.example.com"
    assert_origin_not_allowed "http://#{HOST}", forwarded_host: "proxy.example.com"
  end

  test "X-Forwarded-Host same origin check uses last host in chain" do
    @server.config.allowed_request_origins = []
    @server.config.allow_same_origin_as_host = true
    assert_origin_allowed "http://proxy2.example.com", forwarded_host: "proxy1.example.com, proxy2.example.com"
    assert_origin_not_allowed "http://proxy1.example.com", forwarded_host: "proxy1.example.com, proxy2.example.com"
  end

  test "allow same origin with X-Forwarded-Host and non-standard port" do
    @server.config.allow_same_origin_as_host = true
    assert_origin_allowed "http://proxy.example.com:3000", forwarded_host: "proxy.example.com:3000"
    assert_origin_not_allowed "http://proxy.example.com", forwarded_host: "proxy.example.com:3000"
  end

  test "allow same origin with X-Forwarded-Proto" do
    @server.config.allowed_request_origins = []
    @server.config.allow_same_origin_as_host = true
    assert_origin_allowed "https://#{HOST}", forwarded_proto: "https"
    assert_origin_not_allowed "http://#{HOST}", forwarded_proto: "https"
  end

  private
    def assert_origin_allowed(origin, **options)
      response = connect_with_origin origin, **options
      assert_equal(-1, response[0])
    end

    def assert_origin_not_allowed(origin, **options)
      response = connect_with_origin origin, **options
      assert_equal 404, response[0]
    end

    def connect_with_origin(origin, **options)
      response = nil

      run_in_eventmachine do
        response = Connection.new(@server, env_for_origin(origin, **options)).process
      end

      response
    end

    def env_for_origin(origin, forwarded_host: nil, forwarded_proto: nil)
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket", "SERVER_NAME" => HOST,
        "HTTP_HOST" => HOST, "HTTP_ORIGIN" => origin
      env["HTTP_X_FORWARDED_HOST"] = forwarded_host if forwarded_host
      env["HTTP_X_FORWARDED_PROTO"] = forwarded_proto if forwarded_proto
      env
    end
end
