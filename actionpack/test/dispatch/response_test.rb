# frozen_string_literal: true

require "abstract_unit"
require "timeout"
require "rack/content_length"

class ResponseTest < ActiveSupport::TestCase
  def setup
    @response = ActionDispatch::Response.create
    @response.request = ActionDispatch::Request.empty
  end

  def test_can_wait_until_commit
    t = Thread.new {
      @response.await_commit
    }
    @response.commit!
    assert_predicate @response, :committed?
    assert t.join(0.5)
  end

  def test_stream_close
    @response.stream.close
    assert_predicate @response.stream, :closed?
  end

  def test_stream_write
    @response.stream.write "foo"
    @response.stream.close
    assert_equal "foo", @response.body
  end

  def test_write_after_close
    @response.stream.close

    e = assert_raises(IOError) do
      @response.stream.write "omg"
    end
    assert_equal "closed stream", e.message
  end

  def test_each_isnt_called_if_str_body_is_written
    # Controller writes and reads response body
    each_counter = 0
    @response.body = Object.new.tap { |o| o.singleton_class.send(:define_method, :each) { |&block| each_counter += 1; block.call "foo" } }
    @response["X-Foo"] = @response.body

    assert_equal 1, each_counter, "#each was not called once"

    # Build response
    status, headers, body = @response.to_a

    assert_equal 200, status
    assert_equal "foo", headers["X-Foo"]
    assert_equal "foo", body.each.to_a.join

    # Show that #each was not called twice
    assert_equal 1, each_counter, "#each was not called once"
  end

  def test_set_header_after_read_body_during_action
    @response.body

    # set header after the action reads back @response.body
    @response["x-header"] = "Best of all possible worlds."

    # the response can be built.
    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal "", body.body

    assert_equal "Best of all possible worlds.", headers["x-header"]
  end

  def test_read_body_during_action
    @response.body = "Hello, World!"

    # even though there's no explicitly set content-type,
    assert_nil @response.content_type

    # after the action reads back @response.body,
    assert_equal "Hello, World!", @response.body

    # the response can be built.
    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8"
    }, headers)

    parts = []
    body.each { |part| parts << part }
    assert_equal ["Hello, World!"], parts
  end

  def test_response_body_encoding
    body = ["hello".encode(Encoding::UTF_8)]
    response = ActionDispatch::Response.new 200, {}, body
    response.request = ActionDispatch::Request.empty
    assert_equal Encoding::UTF_8, response.body.encoding
  end

  def test_response_charset_writer
    @response.charset = "utf-16"
    assert_equal "utf-16", @response.charset
    @response.charset = nil
    assert_equal "utf-8", @response.charset
  end

  def test_setting_content_type_header_impacts_content_type_method
    @response.headers["Content-Type"] = "application/aaron"
    assert_equal "application/aaron", @response.content_type
  end

  def test_empty_content_type_returns_nil
    @response.headers["Content-Type"] = ""
    assert_nil @response.content_type
  end

  test "simple output" do
    @response.body = "Hello, World!"

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8"
    }, headers)

    parts = []
    body.each { |part| parts << part }
    assert_equal ["Hello, World!"], parts
  end

  test "status handled properly in initialize" do
    assert_equal 200, ActionDispatch::Response.new("200 OK").status
  end

  def test_only_set_charset_still_defaults_to_text_html
    response = ActionDispatch::Response.new
    response.charset = "utf-16"
    _, headers, _ = response.to_a
    assert_equal "text/html; charset=utf-16", headers["Content-Type"]
  end

  test "utf8 output" do
    @response.body = [1090, 1077, 1089, 1090].pack("U*")

    status, headers, _ = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8"
    }, headers)
  end

  test "content length" do
    [100, 101, 102, 204].each do |c|
      @response = ActionDispatch::Response.new
      @response.status = c.to_s
      @response.set_header "Content-Length", "0"
      _, headers, _ = @response.to_a
      assert !headers.has_key?("Content-Length"), "#{c} must not have a Content-Length header field"
    end
  end

  test "does not contain a message-body" do
    [100, 101, 102, 204, 304].each do |c|
      @response = ActionDispatch::Response.new
      @response.status = c.to_s
      @response.body = "Body must not be included"
      _, _, body = @response.to_a
      assert_empty body, "#{c} must not have a message-body but actually contains #{body}"
    end
  end

  test "content type" do
    [204, 304].each do |c|
      @response = ActionDispatch::Response.new
      @response.status = c.to_s
      _, headers, _ = @response.to_a
      assert !headers.has_key?("Content-Type"), "#{c} should not have Content-Type header"
    end

    [200, 302, 404, 500].each do |c|
      @response = ActionDispatch::Response.new
      @response.status = c.to_s
      _, headers, _ = @response.to_a
      assert headers.has_key?("Content-Type"), "#{c} did not have Content-Type header"
    end
  end

  test "does not include Status header" do
    @response.status = "200 OK"
    _, headers, _ = @response.to_a
    assert_not headers.has_key?("Status")
  end

  test "response code" do
    @response.status = "200 OK"
    assert_equal 200, @response.response_code

    @response.status = "200"
    assert_equal 200, @response.response_code

    @response.status = 200
    assert_equal 200, @response.response_code
  end

  test "code" do
    @response.status = "200 OK"
    assert_equal "200", @response.code

    @response.status = "200"
    assert_equal "200", @response.code

    @response.status = 200
    assert_equal "200", @response.code
  end

  test "message" do
    @response.status = "200 OK"
    assert_equal "OK", @response.message

    @response.status = "200"
    assert_equal "OK", @response.message

    @response.status = 200
    assert_equal "OK", @response.message
  end

  test "cookies" do
    @response.set_cookie("user_name", value: "david", path: "/")
    _status, headers, _body = @response.to_a
    assert_equal "user_name=david; path=/", headers["Set-Cookie"]
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  test "multiple cookies" do
    @response.set_cookie("user_name", value: "david", path: "/")
    @response.set_cookie("login", value: "foo&bar", path: "/", expires: Time.utc(2005, 10, 10, 5))
    _status, headers, _body = @response.to_a
    assert_equal "user_name=david; path=/\nlogin=foo%26bar; path=/; expires=Mon, 10 Oct 2005 05:00:00 -0000", headers["Set-Cookie"]
    assert_equal({ "login" => "foo&bar", "user_name" => "david" }, @response.cookies)
  end

  test "delete cookies" do
    @response.set_cookie("user_name", value: "david", path: "/")
    @response.set_cookie("login", value: "foo&bar", path: "/", expires: Time.utc(2005, 10, 10, 5))
    @response.delete_cookie("login")
    assert_equal({ "user_name" => "david", "login" => nil }, @response.cookies)
  end

  test "read ETag and Cache-Control" do
    resp = ActionDispatch::Response.new.tap { |response|
      response.cache_control[:public] = true
      response.etag = "123"
      response.body = "Hello"
    }
    resp.to_a

    assert_predicate resp, :etag?
    assert_predicate resp, :weak_etag?
    assert_not_predicate resp, :strong_etag?
    assert_equal('W/"202cb962ac59075b964b07152d234b70"', resp.etag)
    assert_equal({ public: true }, resp.cache_control)

    assert_equal("public", resp.headers["Cache-Control"])
    assert_equal('W/"202cb962ac59075b964b07152d234b70"', resp.headers["ETag"])
  end

  test "read strong ETag" do
    resp = ActionDispatch::Response.new.tap { |response|
      response.cache_control[:public] = true
      response.strong_etag = "123"
      response.body = "Hello"
    }
    resp.to_a

    assert_predicate resp, :etag?
    assert_not_predicate resp, :weak_etag?
    assert_predicate resp, :strong_etag?
    assert_equal('"202cb962ac59075b964b07152d234b70"', resp.etag)
  end

  test "read charset and content type" do
    resp = ActionDispatch::Response.new.tap { |response|
      response.charset = "utf-16"
      response.content_type = Mime[:xml]
      response.body = "Hello"
    }
    resp.to_a

    assert_equal("utf-16", resp.charset)
    assert_equal(Mime[:xml], resp.content_type)

    assert_equal("application/xml; charset=utf-16", resp.headers["Content-Type"])
  end

  test "read content type with default charset utf-8" do
    resp = ActionDispatch::Response.new(200, "Content-Type" => "text/xml")
    assert_equal("utf-8", resp.charset)
  end

  test "read content type with charset utf-16" do
    original = ActionDispatch::Response.default_charset
    begin
      ActionDispatch::Response.default_charset = "utf-16"
      resp = ActionDispatch::Response.new(200, "Content-Type" => "text/xml")
      assert_equal("utf-16", resp.charset)
    ensure
      ActionDispatch::Response.default_charset = original
    end
  end

  test "read x_frame_options, x_content_type_options, x_xss_protection, x_download_options and x_permitted_cross_domain_policies, referrer_policy" do
    original_default_headers = ActionDispatch::Response.default_headers
    begin
      ActionDispatch::Response.default_headers = {
        "X-Frame-Options" => "DENY",
        "X-Content-Type-Options" => "nosniff",
        "X-XSS-Protection" => "1;",
        "X-Download-Options" => "noopen",
        "X-Permitted-Cross-Domain-Policies" => "none",
        "Referrer-Policy" => "strict-origin-when-cross-origin"
      }
      resp = ActionDispatch::Response.create.tap { |response|
        response.body = "Hello"
      }
      resp.to_a

      assert_equal("DENY", resp.headers["X-Frame-Options"])
      assert_equal("nosniff", resp.headers["X-Content-Type-Options"])
      assert_equal("1;", resp.headers["X-XSS-Protection"])
      assert_equal("noopen", resp.headers["X-Download-Options"])
      assert_equal("none", resp.headers["X-Permitted-Cross-Domain-Policies"])
      assert_equal("strict-origin-when-cross-origin", resp.headers["Referrer-Policy"])
    ensure
      ActionDispatch::Response.default_headers = original_default_headers
    end
  end

  test "read custom default_header" do
    original_default_headers = ActionDispatch::Response.default_headers
    begin
      ActionDispatch::Response.default_headers = {
        "X-XX-XXXX" => "Here is my phone number"
      }
      resp = ActionDispatch::Response.create.tap { |response|
        response.body = "Hello"
      }
      resp.to_a

      assert_equal("Here is my phone number", resp.headers["X-XX-XXXX"])
    ensure
      ActionDispatch::Response.default_headers = original_default_headers
    end
  end

  test "respond_to? accepts include_private" do
    assert_not_respond_to @response, :method_missing
    assert @response.respond_to?(:method_missing, true)
  end

  test "can be explicitly destructured into status, headers and an enumerable body" do
    response = ActionDispatch::Response.new(404, { "Content-Type" => "text/plain" }, ["Not Found"])
    response.request = ActionDispatch::Request.empty
    status, headers, body = *response

    assert_equal 404, status
    assert_equal({ "Content-Type" => "text/plain" }, headers)
    assert_equal ["Not Found"], body.each.to_a
  end

  test "[response.to_a].flatten does not recurse infinitely" do
    Timeout.timeout(1) do # use a timeout to prevent it stalling indefinitely
      status, headers, body = [@response.to_a].flatten
      assert_equal @response.status, status
      assert_equal @response.headers, headers
      assert_equal @response.body, body.each.to_a.join
    end
  end

  test "compatibility with Rack::ContentLength" do
    @response.body = "Hello"
    app = lambda { |env| @response.to_a }
    env = Rack::MockRequest.env_for("/")

    _status, headers, _body = app.call(env)
    assert_nil headers["Content-Length"]

    _status, headers, _body = Rack::ContentLength.new(app).call(env)
    assert_equal "5", headers["Content-Length"]
  end
end

class ResponseHeadersTest < ActiveSupport::TestCase
  def setup
    @response = ActionDispatch::Response.create
    @response.set_header "Foo", "1"
  end

  test "has_header?" do
    assert @response.has_header? "Foo"
    assert_not @response.has_header? "foo"
    assert_not @response.has_header? nil
  end

  test "get_header" do
    assert_equal "1", @response.get_header("Foo")
    assert_nil @response.get_header("foo")
    assert_nil @response.get_header(nil)
  end

  test "set_header" do
    assert_equal "2", @response.set_header("Foo", "2")
    assert @response.has_header?("Foo")
    assert_equal "2", @response.get_header("Foo")

    assert_nil @response.set_header("Foo", nil)
    assert @response.has_header?("Foo")
    assert_nil @response.get_header("Foo")
  end

  test "delete_header" do
    assert_nil @response.delete_header(nil)

    assert_nil @response.delete_header("foo")
    assert @response.has_header?("Foo")

    assert_equal "1", @response.delete_header("Foo")
    assert_not @response.has_header?("Foo")
  end

  test "add_header" do
    # Add a value to an existing header
    assert_equal "1,2", @response.add_header("Foo", "2")
    assert_equal "1,2", @response.get_header("Foo")

    # Add nil to an existing header
    assert_equal "1,2", @response.add_header("Foo", nil)
    assert_equal "1,2", @response.get_header("Foo")

    # Add nil to a nonexistent header
    assert_nil @response.add_header("Bar", nil)
    assert_not @response.has_header?("Bar")
    assert_nil @response.get_header("Bar")

    # Add a value to a nonexistent header
    assert_equal "1", @response.add_header("Bar", "1")
    assert @response.has_header?("Bar")
    assert_equal "1", @response.get_header("Bar")
  end
end

class ResponseIntegrationTest < ActionDispatch::IntegrationTest
  test "response cache control from railsish app" do
    @app = lambda { |env|
      ActionDispatch::Response.new.tap { |resp|
        resp.cache_control[:public] = true
        resp.etag = "123"
        resp.body = "Hello"
        resp.request = ActionDispatch::Request.empty
      }.to_a
    }

    get "/"
    assert_response :success

    assert_equal("public", @response.headers["Cache-Control"])
    assert_equal('W/"202cb962ac59075b964b07152d234b70"', @response.headers["ETag"])

    assert_equal('W/"202cb962ac59075b964b07152d234b70"', @response.etag)
    assert_equal({ public: true }, @response.cache_control)
  end

  test "response cache control from rackish app" do
    @app = lambda { |env|
      [200,
        { "ETag" => 'W/"202cb962ac59075b964b07152d234b70"',
          "Cache-Control" => "public" }, ["Hello"]]
    }

    get "/"
    assert_response :success

    assert_equal("public", @response.headers["Cache-Control"])
    assert_equal('W/"202cb962ac59075b964b07152d234b70"', @response.headers["ETag"])

    assert_equal('W/"202cb962ac59075b964b07152d234b70"', @response.etag)
    assert_equal({ public: true }, @response.cache_control)
  end

  test "response charset and content type from railsish app" do
    @app = lambda { |env|
      ActionDispatch::Response.new.tap { |resp|
        resp.charset = "utf-16"
        resp.content_type = Mime[:xml]
        resp.body = "Hello"
        resp.request = ActionDispatch::Request.empty
      }.to_a
    }

    get "/"
    assert_response :success

    assert_equal("utf-16", @response.charset)
    assert_equal(Mime[:xml], @response.content_type)

    assert_equal("application/xml; charset=utf-16", @response.headers["Content-Type"])
  end

  test "response charset and content type from rackish app" do
    @app = lambda { |env|
      [200,
        { "Content-Type" => "application/xml; charset=utf-16" },
        ["Hello"]]
    }

    get "/"
    assert_response :success

    assert_equal("utf-16", @response.charset)
    assert_equal(Mime[:xml], @response.content_type)

    assert_equal("application/xml; charset=utf-16", @response.headers["Content-Type"])
  end

  test "strong ETag validator" do
    @app = lambda { |env|
      ActionDispatch::Response.new.tap { |resp|
        resp.strong_etag = "123"
        resp.body = "Hello"
        resp.request = ActionDispatch::Request.empty
      }.to_a
    }

    get "/"
    assert_response :ok

    assert_equal('"202cb962ac59075b964b07152d234b70"', @response.headers["ETag"])
    assert_equal('"202cb962ac59075b964b07152d234b70"', @response.etag)
  end
end
