require File.dirname(__FILE__) + '/../abstract_unit'

class CookieTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def authenticate
      cookie "name" => "user_name", "value" => "david"
      render_text "hello world"
    end

    def access_frozen_cookies
      @cookies["wont"] = "work"
    end

    def rescue_action(e) raise end
  end

  def setup
    @request  = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_setting_cookie
    @request.action = "authenticate"
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david") ], process_request.headers["cookie"]
  end

  def test_setting_cookie
    @request.action = "access_frozen_cookies"
    assert_raises(TypeError) { process_request }
  end

  private
    def process_request
      TestController.process(@request, @response)
    end
end