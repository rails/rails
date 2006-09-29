require File.dirname(__FILE__) + '/../abstract_unit'

class CookieTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def authenticate_with_deprecated_writer
      cookie "name" => "user_name", "value" => "david"
      render_text "hello world"
    end

    def authenticate
      cookies["user_name"] = "david"
      render_text "hello world"
    end

    def authenticate_for_fourten_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.local(2005, 10, 10) }
      render_text "hello world"
    end

    def authenticate_for_fourten_days_with_symbols
      cookies[:user_name] = { :value => "david", :expires => Time.local(2005, 10, 10) }
      render_text "hello world"
    end

    def set_multiple_cookies
      cookies["user_name"] = { "value" => "david", "expires" => Time.local(2005, 10, 10) }
      cookies["login"]     = "XJ-122"
      render_text "hello world"
    end

    def access_frozen_cookies
      cookies["will"] = "work"
      render_text "hello world"
    end

    def rescue_action(e) raise end
  end

  def setup
    @request  = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_setting_cookie_with_deprecated_writer
    @request.action = "authenticate_with_deprecated_writer"
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david") ], process_request.headers["cookie"]
  end

  def test_setting_cookie
    @request.action = "authenticate"
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david") ], process_request.headers["cookie"]
  end

  def test_setting_cookie_for_fourteen_days
    @request.action = "authenticate_for_fourten_days"
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david", "expires" => Time.local(2005, 10, 10)) ], process_request.headers["cookie"]
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    @request.action = "authenticate_for_fourten_days"
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david", "expires" => Time.local(2005, 10, 10)) ], process_request.headers["cookie"]
  end

  def test_multiple_cookies
    @request.action = "set_multiple_cookies"
    assert_equal 2, process_request.headers["cookie"].size
  end

  def test_setting_test_cookie
    @request.action = "access_frozen_cookies"
    assert_nothing_raised { process_request }
  end

  private
    def process_request
      TestController.process(@request, @response)
    end
end
