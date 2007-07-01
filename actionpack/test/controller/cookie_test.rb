require File.dirname(__FILE__) + '/../abstract_unit'

class CookieTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def authenticate_with_deprecated_writer
      cookie "name" => "user_name", "value" => "david"
    end

    def authenticate
      cookies["user_name"] = "david"
    end

    def authenticate_for_fourten_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.local(2005, 10, 10) }
    end

    def authenticate_for_fourten_days_with_symbols
      cookies[:user_name] = { :value => "david", :expires => Time.local(2005, 10, 10) }
    end

    def set_multiple_cookies
      cookies["user_name"] = { "value" => "david", "expires" => Time.local(2005, 10, 10) }
      cookies["login"]     = "XJ-122"
    end

    def access_frozen_cookies
      cookies["will"] = "work"
    end

    def logout
      cookies.delete("user_name")
    end

    def delete_cookie_with_path
      cookies.delete("user_name", :path => '/beaten')
      render_text "hello world"
    end

    def rescue_action(e) 
      raise unless ActionController::MissingTemplate # No templates here, and we don't care about the output 
    end
  end

  def setup
    @request  = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    @controller = TestController.new
    @request.host = "www.nextangle.com"
  end

  def test_setting_cookie_with_deprecated_writer
    get :authenticate_with_deprecated_writer
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david") ], @response.headers["cookie"]
  end

  def test_setting_cookie
    get :authenticate
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david") ], @response.headers["cookie"]
  end

  def test_setting_cookie_for_fourteen_days
    get :authenticate_for_fourten_days
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david", "expires" => Time.local(2005, 10, 10)) ], @response.headers["cookie"]
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    get :authenticate_for_fourten_days
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david", "expires" => Time.local(2005, 10, 10)) ], @response.headers["cookie"]
  end

  def test_multiple_cookies
    get :set_multiple_cookies
    assert_equal 2, @response.cookies.size
  end

  def test_setting_test_cookie
    assert_nothing_raised { get :access_frozen_cookies }
  end
  
  def test_expiring_cookie
    get :logout
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "", "expires" => Time.at(0)) ], @response.headers["cookie"]
  end  
  
  def test_cookiejar_accessor
    @request.cookies["user_name"] = CGI::Cookie.new("name" => "user_name", "value" => "david", "expires" => Time.local(2025, 10, 10))
    @controller.request = @request
    jar = ActionController::CookieJar.new(@controller)
    assert_equal "david", jar["user_name"]
    assert_equal nil, jar["something_else"]
  end

  def test_delete_cookie_with_path
    get :delete_cookie_with_path
    assert_equal "/beaten", @response.headers["cookie"].first.path
    assert_not_equal "/", @response.headers["cookie"].first.path
  end
end
