require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::CrossSiteForgeryTest < ActiveSupport::TestCase
  HOST = 'rubyonrails.com'

  setup do
    @server = TestServer.new
  end

  test "default cross site forgery protection only allows origin same as the server host" do
    assert_origin_allowed 'http://rubyonrails.com'
    assert_origin_not_allowed 'http://hax.com'
  end

  test "disable forgery protection" do
    @server.config.disable_request_forgery_protection = true
    assert_origin_allowed 'http://rubyonrails.com'
    assert_origin_allowed 'http://hax.com'
  end

  test "explicitly specified a single allowed origin" do
    @server.config.allowed_request_origins = 'hax.com'
    assert_origin_not_allowed 'http://rubyonrails.com'
    assert_origin_allowed 'http://hax.com'
  end

  test "explicitly specified multiple allowed origins" do
    @server.config.allowed_request_origins = %w( rubyonrails.com www.rubyonrails.com )
    assert_origin_allowed 'http://rubyonrails.com'
    assert_origin_allowed 'http://www.rubyonrails.com'
    assert_origin_allowed 'https://www.rubyonrails.com'
    assert_origin_not_allowed 'http://hax.com'
  end

  private
    def assert_origin_allowed(origin)
      response = connect_with_origin origin
      assert_equal -1, response[0]
    end

    def assert_origin_not_allowed(origin)
      response = connect_with_origin origin
      assert_equal 404, response[0]
    end

    def connect_with_origin(origin)
      ActionCable::Connection::Base.new(@server, env_for_origin(origin)).process
    end

    def env_for_origin(origin)
      Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket', 'SERVER_NAME' => HOST,
        'HTTP_ORIGIN' => origin
    end
end
