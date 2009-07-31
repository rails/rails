require 'abstract_unit'

class ResponseTest < ActiveSupport::TestCase
  def setup
    @response = ActionDispatch::Response.new
  end

  test "simple output" do
    @response.body = "Hello, World!"
    @response.prepare!

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "max-age=0, private, must-revalidate",
      "ETag" => '"65a8e27d8879283831b664bd8b7f0ad4"',
      "Set-Cookie" => ""
    }, headers)

    parts = []
    body.each { |part| parts << part }
    assert_equal ["Hello, World!"], parts
  end

  test "utf8 output" do
    @response.body = [1090, 1077, 1089, 1090].pack("U*")
    @response.prepare!

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "max-age=0, private, must-revalidate",
      "ETag" => '"ebb5e89e8a94e9dd22abf5d915d112b2"',
      "Set-Cookie" => ""
    }, headers)
  end

  test "streaming block" do
    @response.body = Proc.new do |response, output|
      5.times { |n| output.write(n) }
    end
    @response.prepare!

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "no-cache",
      "Set-Cookie" => ""
    }, headers)

    parts = []
    body.each { |part| parts << part.to_s }
    assert_equal ["0", "1", "2", "3", "4"], parts
  end

  test "content type" do
    [204, 304].each do |c|
      @response.status = c.to_s
      @response.prepare!
      status, headers, body = @response.to_a
      assert !headers.has_key?("Content-Type"), "#{c} should not have Content-Type header"
    end

    [200, 302, 404, 500].each do |c|
      @response.status = c.to_s
      @response.prepare!
      status, headers, body = @response.to_a
      assert headers.has_key?("Content-Type"), "#{c} did not have Content-Type header"
    end
  end

  test "does not include Status header" do
    @response.status = "200 OK"
    @response.prepare!
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
    @response.prepare!
    status, headers, body = @response.to_a
    assert_equal "user_name=david; path=/", headers["Set-Cookie"]
    assert_equal({"user_name" => "david"}, @response.cookies)

    @response.set_cookie("login", :value => "foo&bar", :path => "/", :expires => Time.utc(2005, 10, 10,5))
    @response.prepare!
    status, headers, body = @response.to_a
    assert_equal "user_name=david; path=/\nlogin=foo%26bar; path=/; expires=Mon, 10-Oct-2005 05:00:00 GMT", headers["Set-Cookie"]
    assert_equal({"login" => "foo&bar", "user_name" => "david"}, @response.cookies)
  end
end
