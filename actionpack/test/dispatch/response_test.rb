require 'abstract_unit'

class ResponseTest < ActiveSupport::TestCase
  def setup
    @response = ActionDispatch::Response.new
  end

  test "simple output" do
    @response.body = "Hello, World!"

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "max-age=0, private, must-revalidate",
      "ETag" => '"65a8e27d8879283831b664bd8b7f0ad4"'
    }, headers)

    parts = []
    body.each { |part| parts << part }
    assert_equal ["Hello, World!"], parts
  end

  test "utf8 output" do
    @response.body = [1090, 1077, 1089, 1090].pack("U*")

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "max-age=0, private, must-revalidate",
      "ETag" => '"ebb5e89e8a94e9dd22abf5d915d112b2"'
    }, headers)
  end

  test "streaming block" do
    @response.body = Proc.new do |response, output|
      5.times { |n| output.write(n) }
    end

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "no-cache"
    }, headers)

    parts = []
    body.each { |part| parts << part.to_s }
    assert_equal ["0", "1", "2", "3", "4"], parts
  end

  test "content type" do
    [204, 304].each do |c|
      @response.status = c.to_s
      status, headers, body = @response.to_a
      assert !headers.has_key?("Content-Type"), "#{c} should not have Content-Type header"
    end

    [200, 302, 404, 500].each do |c|
      @response.status = c.to_s
      status, headers, body = @response.to_a
      assert headers.has_key?("Content-Type"), "#{c} did not have Content-Type header"
    end
  end

  test "does not include Status header" do
    @response.status = "200 OK"
    status, headers, body = @response.to_a
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
    assert_equal "user_name=david; path=/\nlogin=foo%26bar; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT", headers["Set-Cookie"]
    assert_equal({"login" => "foo&bar", "user_name" => "david"}, @response.cookies)

    @response.delete_cookie("login")
    status, headers, body = @response.to_a
    assert_equal({"user_name" => "david", "login" => nil}, @response.cookies)
  end

  test "read cache control" do
    resp = ActionDispatch::Response.new.tap { |resp|
      resp.cache_control[:public] = true
      resp.etag = '123'
      resp.body = 'Hello'
    }
    resp.to_a

    assert_equal('"202cb962ac59075b964b07152d234b70"', resp.etag)
    assert_equal({:public => true}, resp.cache_control)

    assert_equal('public', resp.headers['Cache-Control'])
    assert_equal('"202cb962ac59075b964b07152d234b70"', resp.headers['ETag'])
  end

  test "read charset and content type" do
    resp = ActionDispatch::Response.new.tap { |resp|
      resp.charset = 'utf-16'
      resp.content_type = Mime::XML
      resp.body = 'Hello'
    }
    resp.to_a

    assert_equal('utf-16', resp.charset)
    assert_equal(Mime::XML, resp.content_type)

    assert_equal('application/xml; charset=utf-16', resp.headers['Content-Type'])
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
