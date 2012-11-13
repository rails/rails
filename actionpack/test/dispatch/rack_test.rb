require 'abstract_unit'

# TODO: Merge these tests into RequestTest

class BaseRackTest < ActiveSupport::TestCase
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
    @request = ActionDispatch::Request.new(@env)
    # some Nokia phone browsers omit the space after the semicolon separator.
    # some developers have grown accustomed to using comma in cookie values.
    @alt_cookie_fmt_request = ActionDispatch::Request.new(@env.merge({"HTTP_COOKIE"=>"_session_id=c84ace847,96670c052c6ceb2451fb0f2;is_admin=yes"}))
  end

  private
    def set_content_data(data)
      @request.env['REQUEST_METHOD'] = 'POST'
      @request.env['CONTENT_LENGTH'] = data.length
      @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded; charset=utf-8'
      @request.env['rack.input'] = StringIO.new(data)
    end
end

class RackRequestTest < BaseRackTest
  test "proxy request" do
    assert_equal 'glu.ttono.us', @request.host_with_port
  end

  test "http host" do
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "rubyonrails.org:8080"
    assert_equal "rubyonrails.org", @request.host
    assert_equal "rubyonrails.org:8080", @request.host_with_port

    @env['HTTP_X_FORWARDED_HOST'] = "www.firsthost.org, www.secondhost.org"
    assert_equal "www.secondhost.org", @request.host
  end

  test "http host with default port overrides server port" do
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "rubyonrails.org"
    assert_equal "rubyonrails.org", @request.host_with_port
  end

  test "host with port defaults to server name if no host headers" do
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env.delete "HTTP_HOST"
    assert_equal "glu.ttono.us:8007", @request.host_with_port
  end

  test "host with port falls back to server addr if necessary" do
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env.delete "HTTP_HOST"
    @env.delete "SERVER_NAME"
    assert_equal "207.7.108.53", @request.host
    assert_equal 8007, @request.port
    assert_equal "207.7.108.53:8007", @request.host_with_port
  end

  test "host with port if http standard port is specified" do
    @env['HTTP_X_FORWARDED_HOST'] = "glu.ttono.us:80"
    assert_equal "glu.ttono.us", @request.host_with_port
  end

  test "host with port if https standard port is specified" do
    @env['HTTP_X_FORWARDED_PROTO'] = "https"
    @env['HTTP_X_FORWARDED_HOST'] = "glu.ttono.us:443"
    assert_equal "glu.ttono.us", @request.host_with_port
  end

  test "host if ipv6 reference" do
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "[2001:1234:5678:9abc:def0::dead:beef]"
    assert_equal "[2001:1234:5678:9abc:def0::dead:beef]", @request.host
  end

  test "host if ipv6 reference with port" do
    @env.delete "HTTP_X_FORWARDED_HOST"
    @env['HTTP_HOST'] = "[2001:1234:5678:9abc:def0::dead:beef]:8008"
    assert_equal "[2001:1234:5678:9abc:def0::dead:beef]", @request.host
  end

  test "cgi environment variables" do
    assert_equal "Basic", @request.auth_type
    assert_equal 0, @request.content_length
    assert_equal nil, @request.content_mime_type
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
    assert_equal "GET", @request.request_method
    assert_equal "/dispatch.fcgi", @request.script_name
    assert_equal "glu.ttono.us", @request.server_name
    assert_equal 8007, @request.server_port
    assert_equal "HTTP/1.1", @request.server_protocol
    assert_equal "lighttpd", @request.server_software
  end

  test "cookie syntax resilience" do
    cookies = @request.cookies
    assert_equal "c84ace84796670c052c6ceb2451fb0f2", cookies["_session_id"], cookies.inspect
    assert_equal "yes", cookies["is_admin"], cookies.inspect

    alt_cookies = @alt_cookie_fmt_request.cookies
    #assert_equal "c84ace847,96670c052c6ceb2451fb0f2", alt_cookies["_session_id"], alt_cookies.inspect
    assert_equal "yes", alt_cookies["is_admin"], alt_cookies.inspect
  end
end

class RackRequestParamsParsingTest < BaseRackTest
  test "doesnt break when content type has charset" do
    set_content_data 'flamenco=love'

    assert_equal({"flamenco"=> "love"}, @request.request_parameters)
  end

  test "doesnt interpret request uri as query string when missing" do
    @request.env['REQUEST_URI'] = 'foo'
    assert_equal({}, @request.query_parameters)
  end
end

class RackRequestContentTypeTest < BaseRackTest
  test "html content type verification" do
    assert_deprecated do
      @request.env['CONTENT_TYPE'] = Mime::HTML.to_s
      assert @request.content_mime_type.verify_request?
    end
  end

  test "xml content type verification" do
    assert_deprecated do
      @request.env['CONTENT_TYPE'] = Mime::XML.to_s
      assert !@request.content_mime_type.verify_request?
    end
  end
end

class RackRequestNeedsRewoundTest < BaseRackTest
  test "body should be rewound" do
    data = 'foo'
    @env['rack.input'] = StringIO.new(data)
    @env['CONTENT_LENGTH'] = data.length
    @env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded; charset=utf-8'

    # Read the request body by parsing params.
    request = ActionDispatch::Request.new(@env)
    request.request_parameters

    # Should have rewound the body.
    assert_equal 0, request.body.pos
  end
end
