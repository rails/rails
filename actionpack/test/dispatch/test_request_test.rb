require 'abstract_unit'

class TestRequestTest < ActiveSupport::TestCase
  test "sane defaults" do
    env = ActionDispatch::TestRequest.new.env

    assert_equal "GET", env.delete("REQUEST_METHOD")
    assert_equal "off", env.delete("HTTPS")
    assert_equal "http", env.delete("rack.url_scheme")
    assert_equal "example.org", env.delete("SERVER_NAME")
    assert_equal "80", env.delete("SERVER_PORT")
    assert_equal "/", env.delete("PATH_INFO")
    assert_equal "", env.delete("SCRIPT_NAME")
    assert_equal "", env.delete("QUERY_STRING")
    assert_equal "0", env.delete("CONTENT_LENGTH")

    assert_equal "test.host", env.delete("HTTP_HOST")
    assert_equal "0.0.0.0", env.delete("REMOTE_ADDR")
    assert_equal "Rails Testing", env.delete("HTTP_USER_AGENT")

    assert_equal [1, 2], env.delete("rack.version")
    assert_equal "", env.delete("rack.input").string
    assert_kind_of StringIO, env.delete("rack.errors")
    assert_equal true, env.delete("rack.multithread")
    assert_equal true, env.delete("rack.multiprocess")
    assert_equal false, env.delete("rack.run_once")

    assert env.empty?, env.inspect
  end

  test "cookie jar" do
    req = ActionDispatch::TestRequest.new

    assert_equal({}, req.cookies)
    assert_equal nil, req.env["HTTP_COOKIE"]

    req.cookie_jar["user_name"] = "david"
    assert_cookies({"user_name" => "david"}, req.cookie_jar)

    req.cookie_jar["login"] = "XJ-122"
    assert_cookies({"user_name" => "david", "login" => "XJ-122"}, req.cookie_jar)

    assert_nothing_raised do
      req.cookie_jar["login"] = nil
      assert_cookies({"user_name" => "david", "login" => nil}, req.cookie_jar)
    end

    req.cookie_jar.delete(:login)
    assert_cookies({"user_name" => "david"}, req.cookie_jar)

    req.cookie_jar.clear
    assert_cookies({}, req.cookie_jar)

    req.cookie_jar.update(:user_name => "david")
    assert_cookies({"user_name" => "david"}, req.cookie_jar)
  end

  test "does not complain when Rails.application is nil" do
    Rails.stubs(:application).returns(nil)
    req = ActionDispatch::TestRequest.new

    assert_equal false, req.env.empty?
  end

  private
    def assert_cookies(expected, cookie_jar)
      assert_equal(expected, cookie_jar.instance_variable_get("@cookies"))
    end
end
