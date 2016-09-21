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
  end

  teardown do
    @server.config.disable_request_forgery_protection = false
    @server.config.allowed_request_origins = []
    @server.config.allow_same_origin_as_host = false
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

  private
    def assert_origin_allowed(origin)
      response = connect_with_origin origin
      assert_equal(-1, response[0])
    end

    def assert_origin_not_allowed(origin)
      response = connect_with_origin origin
      assert_equal 404, response[0]
    end

    def connect_with_origin(origin)
      response = nil

      run_in_eventmachine do
        response = Connection.new(@server, env_for_origin(origin)).process
      end

      response
    end

    def env_for_origin(origin)
      Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket", "SERVER_NAME" => HOST,
        "HTTP_HOST" => HOST, "HTTP_ORIGIN" => origin
    end
end
