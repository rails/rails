require 'abstract_unit'

class CookieTest < ActionController::TestCase
  class TestController < ActionController::Base
    def authenticate
      cookies["user_name"] = "david"
    end

    def set_with_with_escapable_characters
      cookies["that & guy"] = "foo & bar => baz"
    end

    def authenticate_for_fourteen_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
    end

    def authenticate_for_fourteen_days_with_symbols
      cookies[:user_name] = { :value => "david", :expires => Time.utc(2005, 10, 10,5) }
    end

    def set_multiple_cookies
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
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
      cookies["user_name"] = { :value => "david", :httponly => true }
    end

    def rescue_action(e)
      raise unless ActionView::MissingTemplate # No templates here, and we don't care about the output
    end
  end

  tests TestController

  def setup
    @request.host = "www.nextangle.com"
  end

  def test_setting_cookie
    get :authenticate
    assert_equal ["user_name=david; path=/"], @response.headers["Set-Cookie"]
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_with_escapable_characters
    get :set_with_with_escapable_characters
    assert_equal ["that+%26+guy=foo+%26+bar+%3D%3E+baz; path=/"], @response.headers["Set-Cookie"]
    assert_equal({"that & guy" => "foo & bar => baz"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days
    get :authenticate_for_fourteen_days
    assert_equal ["user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT"], @response.headers["Set-Cookie"]
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    get :authenticate_for_fourteen_days_with_symbols
    assert_equal ["user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT"], @response.headers["Set-Cookie"]
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_http_only
    get :authenticate_with_http_only
    assert_equal ["user_name=david; path=/; HttpOnly"], @response.headers["Set-Cookie"]
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_multiple_cookies
    get :set_multiple_cookies
    assert_equal 2, @response.cookies.size
    assert_equal "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT", @response.headers["Set-Cookie"][0]
    assert_equal "login=XJ-122; path=/", @response.headers["Set-Cookie"][1]
    assert_equal({"login" => "XJ-122", "user_name" => "david"}, @response.cookies)
  end

  def test_setting_test_cookie
    assert_nothing_raised { get :access_frozen_cookies }
  end

  def test_expiring_cookie
    get :logout
    assert_equal ["user_name=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT"], @response.headers["Set-Cookie"]
    assert_equal({"user_name" => nil}, @response.cookies)
  end

  def test_cookiejar_accessor
    @request.cookies["user_name"] = "david"
    @controller.request = @request
    jar = ActionController::CookieJar.new(@controller)
    assert_equal "david", jar["user_name"]
    assert_equal nil, jar["something_else"]
  end

  def test_cookiejar_accessor_with_array_value
    @request.cookies["pages"] = %w{1 2 3}
    @controller.request = @request
    jar = ActionController::CookieJar.new(@controller)
    assert_equal %w{1 2 3}, jar["pages"]
  end

  def test_delete_cookie_with_path
    get :delete_cookie_with_path
    assert_equal ["user_name=; path=/beaten; expires=Thu, 01-Jan-1970 00:00:00 GMT"], @response.headers["Set-Cookie"]
  end

  def test_cookies_persist_throughout_request
    get :authenticate
    cookies = @controller.send(:cookies)
    assert_equal 'david', cookies['user_name']
  end
end
