require 'abstract_unit'

class TestRequestTest < ActiveSupport::TestCase
  test "sane defaults" do
    env = ActionDispatch::TestRequest.create.env

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

    assert_equal [1, 3], env.delete("rack.version")
    assert_equal "", env.delete("rack.input").string
    assert_kind_of StringIO, env.delete("rack.errors")
    assert_equal true, env.delete("rack.multithread")
    assert_equal true, env.delete("rack.multiprocess")
    assert_equal false, env.delete("rack.run_once")
  end

  test "cookie jar" do
    req = ActionDispatch::TestRequest.create({})

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

  test "does not complain when there is no application config" do
    req = ActionDispatch::TestRequest.create({})
    assert_equal false, req.env.empty?
  end

  test "default remote address is 0.0.0.0" do
    req = ActionDispatch::TestRequest.create({})
    assert_equal '0.0.0.0', req.remote_addr
  end

  test "allows remote address to be overridden" do
    req = ActionDispatch::TestRequest.create('REMOTE_ADDR' => '127.0.0.1')
    assert_equal '127.0.0.1', req.remote_addr
  end

  test "default host is test.host" do
    req = ActionDispatch::TestRequest.create({})
    assert_equal 'test.host', req.host
  end

  test "allows host to be overridden" do
    req = ActionDispatch::TestRequest.create('HTTP_HOST' => 'www.example.com')
    assert_equal 'www.example.com', req.host
  end

  test "default user agent is 'Rails Testing'" do
    req = ActionDispatch::TestRequest.create({})
    assert_equal 'Rails Testing', req.user_agent
  end

  test "allows user agent to be overridden" do
    req = ActionDispatch::TestRequest.create('HTTP_USER_AGENT' => 'GoogleBot')
    assert_equal 'GoogleBot', req.user_agent
  end

  test "setter methods" do
    req = ActionDispatch::TestRequest.create({})
    get = 'GET'

    [
      'request_method=', 'host=', 'request_uri=', 'path=', 'if_modified_since=', 'if_none_match=',
      'remote_addr=', 'user_agent=', 'accept='
    ].each do |method|
      req.send(method, get)
    end

    req.port = 8080
    req.accept = 'hello goodbye'

    assert_equal(get, req.get_header('REQUEST_METHOD'))
    assert_equal(get, req.get_header('HTTP_HOST'))
    assert_equal(8080, req.get_header('SERVER_PORT'))
    assert_equal(get, req.get_header('REQUEST_URI'))
    assert_equal(get, req.get_header('PATH_INFO'))
    assert_equal(get, req.get_header('HTTP_IF_MODIFIED_SINCE'))
    assert_equal(get, req.get_header('HTTP_IF_NONE_MATCH'))
    assert_equal(get, req.get_header('REMOTE_ADDR'))
    assert_equal(get, req.get_header('HTTP_USER_AGENT'))
    assert_nil(req.get_header('action_dispatch.request.accepts'))
    assert_equal('hello goodbye', req.get_header('HTTP_ACCEPT'))
  end

  private
    def assert_cookies(expected, cookie_jar)
      assert_equal(expected, cookie_jar.instance_variable_get("@cookies"))
    end
end
