require File.dirname(__FILE__) + '/../abstract_unit'

class CookieTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def authenticate
      cookies["user_name"] = "david"
    end

    def authenticate_for_fourteen_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.local(2005, 10, 10) }
    end

    def authenticate_for_fourteen_days_with_symbols
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
      render :text => "hello world"
    end

    def authenticate_with_http_only
      cookies["user_name"] = { :value => "david", :http_only => true }
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

  def test_setting_cookie
    get :authenticate
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david") ], @response.headers["cookie"]
  end

  def test_setting_cookie_for_fourteen_days
    get :authenticate_for_fourteen_days
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david", "expires" => Time.local(2005, 10, 10)) ], @response.headers["cookie"]
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    get :authenticate_for_fourteen_days
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david", "expires" => Time.local(2005, 10, 10)) ], @response.headers["cookie"]
  end

  def test_setting_cookie_with_http_only
    get :authenticate_with_http_only
    assert_equal [ CGI::Cookie::new("name" => "user_name", "value" => "david", "http_only" => true) ], @response.headers["cookie"]
    assert_equal CGI::Cookie::new("name" => "user_name", "value" => "david", "path" => "/", "http_only" => true).to_s, @response.headers["cookie"][0].to_s
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

  def test_cookiejar_accessor_with_array_value
    a = %w{1 2 3}
    @request.cookies["pages"] = CGI::Cookie.new("name" => "pages", "value" => a, "expires" => Time.local(2025, 10, 10))
    @controller.request = @request
    jar = ActionController::CookieJar.new(@controller)
    assert_equal a, jar["pages"]
  end
  
  def test_delete_cookie_with_path
    get :delete_cookie_with_path
    assert_equal "/beaten", @response.headers["cookie"].first.path
    assert_not_equal "/", @response.headers["cookie"].first.path
  end

  def test_cookie_to_s_simple_values
    assert_equal 'myname=myvalue; path=', CGI::Cookie.new('myname', 'myvalue').to_s
  end

  def test_cookie_to_s_hash
    cookie_str = CGI::Cookie.new(
      'name' => 'myname',
      'value' => 'myvalue',
      'domain' => 'mydomain',
      'path' => 'mypath',
      'expires' => Time.utc(2007, 10, 20),
      'secure' => true,
      'http_only' => true).to_s
    assert_equal 'myname=myvalue; domain=mydomain; path=mypath; expires=Sat, 20 Oct 2007 00:00:00 GMT; secure; HttpOnly', cookie_str
  end

  def test_cookie_to_s_hash_default_not_secure_not_http_only
    cookie_str = CGI::Cookie.new(
      'name' => 'myname',
      'value' => 'myvalue',
      'domain' => 'mydomain',
      'path' => 'mypath',
      'expires' => Time.utc(2007, 10, 20))
    assert cookie_str !~ /secure/
    assert cookie_str !~ /HttpOnly/
  end
end
