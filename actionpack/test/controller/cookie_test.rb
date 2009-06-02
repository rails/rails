require 'abstract_unit'

class CookieTest < ActionController::TestCase
  class TestController < ActionController::Base
    def authenticate
      cookies["user_name"] = "david"
      head :ok
    end

    def set_with_with_escapable_characters
      cookies["that & guy"] = "foo & bar => baz"
      head :ok
    end

    def authenticate_for_fourteen_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def authenticate_for_fourteen_days_with_symbols
      cookies[:user_name] = { :value => "david", :expires => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def set_multiple_cookies
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
      cookies["login"]     = "XJ-122"
      head :ok
    end

    def access_frozen_cookies
      cookies["will"] = "work"
      head :ok
    end

    def logout
      cookies.delete("user_name")
      head :ok
    end

    def delete_cookie_with_path
      cookies.delete("user_name", :path => '/beaten')
      head :ok
    end

    def authenticate_with_http_only
      cookies["user_name"] = { :value => "david", :httponly => true }
      head :ok
    end
  end

  tests TestController

  def setup
    super
    @request.host = "www.nextangle.com"
  end

  def test_setting_cookie
    get :authenticate
    assert_cookie_header "user_name=david; path=/"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_with_escapable_characters
    get :set_with_with_escapable_characters
    assert_cookie_header "that+%26+guy=foo+%26+bar+%3D%3E+baz; path=/"
    assert_equal({"that & guy" => "foo & bar => baz"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days
    get :authenticate_for_fourteen_days
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    get :authenticate_for_fourteen_days_with_symbols
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_http_only
    get :authenticate_with_http_only
    assert_cookie_header "user_name=david; path=/; HttpOnly"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_multiple_cookies
    get :set_multiple_cookies
    assert_equal 2, @response.cookies.size
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT\nlogin=XJ-122; path=/"
    assert_equal({"login" => "XJ-122", "user_name" => "david"}, @response.cookies)
  end

  def test_setting_test_cookie
    assert_nothing_raised { get :access_frozen_cookies }
  end

  def test_expiring_cookie
    get :logout
    assert_cookie_header "user_name=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT"
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
    assert_cookie_header "user_name=; path=/beaten; expires=Thu, 01-Jan-1970 00:00:00 GMT"
  end

  def test_cookies_persist_throughout_request
    get :authenticate
    cookies = @controller.send(:cookies)
    assert_equal 'david', cookies['user_name']
  end
  
  private
    def assert_cookie_header(expected)
      header = @response.headers["Set-Cookie"]
      if header.respond_to?(:to_str)
        assert_equal expected, header
      else
        assert_equal expected.split("\n"), header
      end
    end
end
