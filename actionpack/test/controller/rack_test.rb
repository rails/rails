require 'abstract_unit'

class BaseRackTest < Test::Unit::TestCase
  def setup
    @env = {
      "HTTP_MAX_FORWARDS" => "10",
      "SERVER_NAME" => "glu.ttono.us",
      "FCGI_ROLE" => "RESPONDER",
      "AUTH_TYPE" => "Basic",
      "HTTP_X_FORWARDED_HOST" => "glu.ttono.us",
      "HTTP_ACCEPT_CHARSET" => "UTF-8",
      "HTTP_ACCEPT_ENCODING" => "gzip, deflate",
      "HTTP_CACHE_CONTROL" => "no-cache, max-age=0",
      "HTTP_PRAGMA" => "no-cache",
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en)",
      "PATH_INFO" => "/homepage/",
      "HTTP_ACCEPT_LANGUAGE" => "en",
      "HTTP_NEGOTIATE" => "trans",
      "HTTP_HOST" => "glu.ttono.us:8007",
      "HTTP_REFERER" => "http://www.google.com/search?q=glu.ttono.us",
      "HTTP_FROM" => "googlebot",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "REDIRECT_URI" => "/dispatch.fcgi",
      "SCRIPT_NAME" => "/dispatch.fcgi",
      "SERVER_ADDR" => "207.7.108.53",
      "REMOTE_ADDR" => "207.7.108.53",
      "REMOTE_HOST" => "google.com",
      "REMOTE_IDENT" => "kevin",
      "REMOTE_USER" => "kevin",
      "SERVER_SOFTWARE" => "lighttpd/1.4.5",
      "HTTP_COOKIE" => "_session_id=c84ace84796670c052c6ceb2451fb0f2; is_admin=yes",
      "HTTP_X_FORWARDED_SERVER" => "glu.ttono.us",
      "REQUEST_URI" => "/admin",
      "DOCUMENT_ROOT" => "/home/kevinc/sites/typo/public",
      "PATH_TRANSLATED" => "/home/kevinc/sites/typo/public/homepage/",
      "SERVER_PORT" => "8007",
      "QUERY_STRING" => "",
      "REMOTE_PORT" => "63137",
      "GATEWAY_INTERFACE" => "CGI/1.1",
      "HTTP_X_FORWARDED_FOR" => "65.88.180.234",
      "HTTP_ACCEPT" => "*/*",
      "SCRIPT_FILENAME" => "/home/kevinc/sites/typo/public/dispatch.fcgi",
      "REDIRECT_STATUS" => "200",
      "REQUEST_METHOD" => "GET"
    }
    @request = ActionController::Request.new(@env)
    # some Nokia phone browsers omit the space after the semicolon separator.
    # some developers have grown accustomed to using comma in cookie values.
    @alt_cookie_fmt_request = ActionController::Request.new(@env.merge({"HTTP_COOKIE"=>"_session_id=c84ace847,96670c052c6ceb2451fb0f2;is_admin=yes"}))
  end

  def default_test; end

  private

  def set_content_data(data)
    @request.env['REQUEST_METHOD'] = 'POST'
    @request.env['CONTENT_LENGTH'] = data.length
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded; charset=utf-8'
    @request.env['rack.input'] = StringIO.new(data)
  end
end

class RackRequestTest < BaseRackTest
  def test_proxy_request
    assert_equal 'glu.ttono.us', @request.host_with_port
  end

  def test_http_host
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "rubyonrails.org:8080"
    assert_equal "rubyonrails.org", @request.host
    assert_equal "rubyonrails.org:8080", @request.host_with_port

    @env['HTTP_X_FORWARDED_HOST'] = "www.firsthost.org, www.secondhost.org"
    assert_equal "www.secondhost.org", @request.host
  end

  def test_http_host_with_default_port_overrides_server_port
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "rubyonrails.org"
    assert_equal "rubyonrails.org", @request.host_with_port
  end

  def test_host_with_port_defaults_to_server_name_if_no_host_headers
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env.delete "HTTP_HOST"
    assert_equal "glu.ttono.us:8007", @request.host_with_port
  end

  def test_host_with_port_falls_back_to_server_addr_if_necessary
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env.delete "HTTP_HOST"
    @env.delete "SERVER_NAME"
    assert_equal "207.7.108.53", @request.host
    assert_equal 8007, @request.port
    assert_equal "207.7.108.53:8007", @request.host_with_port
  end

  def test_host_with_port_if_http_standard_port_is_specified
    @env['HTTP_X_FORWARDED_HOST'] = "glu.ttono.us:80"
    assert_equal "glu.ttono.us", @request.host_with_port
  end

  def test_host_with_port_if_https_standard_port_is_specified
    @env['HTTP_X_FORWARDED_PROTO'] = "https"
    @env['HTTP_X_FORWARDED_HOST'] = "glu.ttono.us:443"
    assert_equal "glu.ttono.us", @request.host_with_port
  end

  def test_host_if_ipv6_reference
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "[2001:1234:5678:9abc:def0::dead:beef]"
    assert_equal "[2001:1234:5678:9abc:def0::dead:beef]", @request.host
  end

  def test_host_if_ipv6_reference_with_port
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "[2001:1234:5678:9abc:def0::dead:beef]:8008"
    assert_equal "[2001:1234:5678:9abc:def0::dead:beef]", @request.host
  end

  def test_cgi_environment_variables
    assert_equal "Basic", @request.auth_type
    assert_equal 0, @request.content_length
    assert_equal nil, @request.content_type
    assert_equal "CGI/1.1", @request.gateway_interface
    assert_equal "*/*", @request.accept
    assert_equal "UTF-8", @request.accept_charset
    assert_equal "gzip, deflate", @request.accept_encoding
    assert_equal "en", @request.accept_language
    assert_equal "no-cache, max-age=0", @request.cache_control
    assert_equal "googlebot", @request.from
    assert_equal "glu.ttono.us", @request.host
    assert_equal "trans", @request.negotiate
    assert_equal "no-cache", @request.pragma
    assert_equal "http://www.google.com/search?q=glu.ttono.us", @request.referer
    assert_equal "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en)", @request.user_agent
    assert_equal "/homepage/", @request.path_info
    assert_equal "/home/kevinc/sites/typo/public/homepage/", @request.path_translated
    assert_equal "", @request.query_string
    assert_equal "207.7.108.53", @request.remote_addr
    assert_equal "google.com", @request.remote_host
    assert_equal "kevin", @request.remote_ident
    assert_equal "kevin", @request.remote_user
    assert_equal :get, @request.request_method
    assert_equal "/dispatch.fcgi", @request.script_name
    assert_equal "glu.ttono.us", @request.server_name
    assert_equal 8007, @request.server_port
    assert_equal "HTTP/1.1", @request.server_protocol
    assert_equal "lighttpd", @request.server_software
  end

  def test_cookie_syntax_resilience
    cookies = @request.cookies
    assert_equal "c84ace84796670c052c6ceb2451fb0f2", cookies["_session_id"], cookies.inspect
    assert_equal "yes", cookies["is_admin"], cookies.inspect

    alt_cookies = @alt_cookie_fmt_request.cookies
    #assert_equal "c84ace847,96670c052c6ceb2451fb0f2", alt_cookies["_session_id"], alt_cookies.inspect
    assert_equal "yes", alt_cookies["is_admin"], alt_cookies.inspect
  end
end

class RackRequestParamsParsingTest < BaseRackTest
  def test_doesnt_break_when_content_type_has_charset
    set_content_data 'flamenco=love'

    assert_equal({"flamenco"=> "love"}, @request.request_parameters)
  end

  def test_doesnt_interpret_request_uri_as_query_string_when_missing
    @request.env['REQUEST_URI'] = 'foo'
    assert_equal({}, @request.query_parameters)
  end
end

class RackRequestContentTypeTest < BaseRackTest
  def test_html_content_type_verification
    @request.env['CONTENT_TYPE'] = Mime::HTML.to_s
    assert @request.content_type.verify_request?
  end

  def test_xml_content_type_verification
    @request.env['CONTENT_TYPE'] = Mime::XML.to_s
    assert !@request.content_type.verify_request?
  end
end

class RackRequestNeedsRewoundTest < BaseRackTest
  def test_body_should_be_rewound
    data = 'foo'
    @env['rack.input'] = StringIO.new(data)
    @env['CONTENT_LENGTH'] = data.length
    @env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded; charset=utf-8'

    # Read the request body by parsing params.
    request = ActionController::Request.new(@env)
    request.request_parameters

    # Should have rewound the body.
    assert_equal 0, request.body.pos
  end
end

class RackResponseTest < BaseRackTest
  def setup
    super
    @response = ActionController::Response.new
  end

  def test_simple_output
    @response.body = "Hello, World!"
    @response.prepare!

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "private, max-age=0, must-revalidate",
      "ETag" => '"65a8e27d8879283831b664bd8b7f0ad4"',
      "Set-Cookie" => "",
      "Content-Length" => "13"
    }, headers)

    parts = []
    body.each { |part| parts << part }
    assert_equal ["Hello, World!"], parts
  end

  def test_utf8_output
    @response.body = [1090, 1077, 1089, 1090].pack("U*")
    @response.prepare!

    status, headers, body = @response.to_a
    assert_equal 200, status
    assert_equal({
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "private, max-age=0, must-revalidate",
      "ETag" => '"ebb5e89e8a94e9dd22abf5d915d112b2"',
      "Set-Cookie" => "",
      "Content-Length" => "8"
    }, headers)
  end

  def test_streaming_block
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
    body.each { |part| parts << part }
    assert_equal ["0", "1", "2", "3", "4"], parts
  end
end

class RackResponseHeadersTest < BaseRackTest
  def setup
    super
    @response = ActionController::Response.new
    @response.status = "200 OK"
  end

  def test_content_type
    [204, 304].each do |c|
      @response.status = c.to_s
      assert !response_headers.has_key?("Content-Type"), "#{c} should not have Content-Type header"
    end

    [200, 302, 404, 500].each do |c|
      @response.status = c.to_s
      assert response_headers.has_key?("Content-Type"), "#{c} did not have Content-Type header"
    end
  end

  def test_status
    assert !response_headers.has_key?('Status')
  end

  private
    def response_headers
      @response.prepare!
      @response.to_a[1]
    end
end
