require 'abstract_unit'

class ResponseTest < ActiveSupport::TestCase
  def setup
    @response = ActionDispatch::Response.new
  end

  def test_can_wait_until_commit
    t = Thread.new {
      @response.await_commit
    }
    @response.commit!
    assert @response.committed?
    assert t.join(0.5)
  end

  def test_stream_close
    @response.stream.close
    assert @response.stream.closed?
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

  def test_response_body_encoding
    body = ["hello".encode(Encoding::UTF_8)]
    response = ActionDispatch::Response.new 200, {}, body
    assert_equal Encoding::UTF_8, response.body.encoding
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
    assert_equal 200, ActionDispatch::Response.new('200 OK').status
  end

  test "utf8 output" do
    @response.body = [1090, 1077, 1089, 1090].pack("U*")

    status, headers, _ = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8"
    }, headers)
  end

  test "content type" do
    [204, 304].each do |c|
      @response.status = c.to_s
      _, headers, _ = @response.to_a
      assert !headers.has_key?("Content-Type"), "#{c} should not have Content-Type header"
    end

    [200, 302, 404, 500].each do |c|
      @response.status = c.to_s
      _, headers, _ = @response.to_a
      assert headers.has_key?("Content-Type"), "#{c} did not have Content-Type header"
    end
  end

  test "does not include Status header" do
    @response.status = "200 OK"
    _, headers, _ = @response.to_a
    assert !headers.has_key?('Status')
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
    @response.set_cookie("user_name", :value => "david", :path => "/")
    status, headers, body = @response.to_a
    assert_equal "user_name=david; path=/", headers["Set-Cookie"]
    assert_equal({"user_name" => "david"}, @response.cookies)

    @response.set_cookie("login", :value => "foo&bar", :path => "/", :expires => Time.utc(2005, 10, 10,5))
    status, headers, body = @response.to_a
    assert_equal "user_name=david; path=/\nlogin=foo%26bar; path=/; expires=Mon, 10 Oct 2005 05:00:00 -0000", headers["Set-Cookie"]
    assert_equal({"login" => "foo&bar", "user_name" => "david"}, @response.cookies)

    @response.delete_cookie("login")
    status, headers, body = @response.to_a
    assert_equal({"user_name" => "david", "login" => nil}, @response.cookies)
  end

  test "read cache control" do
    resp = ActionDispatch::Response.new.tap { |response|
      response.cache_control[:public] = true
      response.etag = '123'
      response.body = 'Hello'
    }
    resp.to_a

    assert_equal('"202cb962ac59075b964b07152d234b70"', resp.etag)
    assert_equal({:public => true}, resp.cache_control)

    assert_equal('public', resp.headers['Cache-Control'])
    assert_equal('"202cb962ac59075b964b07152d234b70"', resp.headers['ETag'])
  end

  test "read charset and content type" do
    resp = ActionDispatch::Response.new.tap { |response|
      response.charset = 'utf-16'
      response.content_type = Mime::XML
      response.body = 'Hello'
    }
    resp.to_a

    assert_equal('utf-16', resp.charset)
    assert_equal(Mime::XML, resp.content_type)

    assert_equal('application/xml; charset=utf-16', resp.headers['Content-Type'])
  end

  test "read content type without charset" do
    original = ActionDispatch::Response.default_charset
    begin
      ActionDispatch::Response.default_charset = 'utf-16'
      resp = ActionDispatch::Response.new(200, { "Content-Type" => "text/xml" })
      assert_equal('utf-16', resp.charset)
    ensure
      ActionDispatch::Response.default_charset = original
    end
  end

  test "read x_frame_options, x_content_type_options and x_xss_protection" do
    begin
      ActionDispatch::Response.default_headers = {
        'X-Frame-Options' => 'DENY',
        'X-Content-Type-Options' => 'nosniff',
        'X-XSS-Protection' => '1;',
        'X-UA-Compatible' => 'chrome=1'
      }
      resp = ActionDispatch::Response.new.tap { |response|
        response.body = 'Hello'
      }
      resp.to_a

      assert_equal('DENY', resp.headers['X-Frame-Options'])
      assert_equal('nosniff', resp.headers['X-Content-Type-Options'])
      assert_equal('1;', resp.headers['X-XSS-Protection'])
      assert_equal('chrome=1', resp.headers['X-UA-Compatible'])
    ensure
      ActionDispatch::Response.default_headers = nil
    end
  end

  test "read custom default_header" do
    begin
      ActionDispatch::Response.default_headers = {
        'X-XX-XXXX' => 'Here is my phone number'
      }
      resp = ActionDispatch::Response.new.tap { |response|
        response.body = 'Hello'
      }
      resp.to_a

      assert_equal('Here is my phone number', resp.headers['X-XX-XXXX'])
    ensure
      ActionDispatch::Response.default_headers = nil
    end
  end
end

class ResponseIntegrationTest < ActionDispatch::IntegrationTest
  def app
    @app
  end

  test "response cache control from railsish app" do
    @app = lambda { |env|
      ActionDispatch::Response.new.tap { |resp|
        resp.cache_control[:public] = true
        resp.etag = '123'
        resp.body = 'Hello'
      }.to_a
    }

    get '/'
    assert_response :success

    assert_equal('public', @response.headers['Cache-Control'])
    assert_equal('"202cb962ac59075b964b07152d234b70"', @response.headers['ETag'])

    assert_equal('"202cb962ac59075b964b07152d234b70"', @response.etag)
    assert_equal({:public => true}, @response.cache_control)
  end

  test "response cache control from rackish app" do
    @app = lambda { |env|
      [200,
        {'ETag' => '"202cb962ac59075b964b07152d234b70"',
          'Cache-Control' => 'public'}, ['Hello']]
    }

    get '/'
    assert_response :success

    assert_equal('public', @response.headers['Cache-Control'])
    assert_equal('"202cb962ac59075b964b07152d234b70"', @response.headers['ETag'])

    assert_equal('"202cb962ac59075b964b07152d234b70"', @response.etag)
    assert_equal({:public => true}, @response.cache_control)
  end

  test "response charset and content type from railsish app" do
    @app = lambda { |env|
      ActionDispatch::Response.new.tap { |resp|
        resp.charset = 'utf-16'
        resp.content_type = Mime::XML
        resp.body = 'Hello'
      }.to_a
    }

    get '/'
    assert_response :success

    assert_equal('utf-16', @response.charset)
    assert_equal(Mime::XML, @response.content_type)

    assert_equal('application/xml; charset=utf-16', @response.headers['Content-Type'])
  end

  test "response charset and content type from rackish app" do
    @app = lambda { |env|
      [200,
        {'Content-Type' => 'application/xml; charset=utf-16'},
        ['Hello']]
    }

    get '/'
    assert_response :success

    assert_equal('utf-16', @response.charset)
    assert_equal(Mime::XML, @response.content_type)

    assert_equal('application/xml; charset=utf-16', @response.headers['Content-Type'])
  end
end
