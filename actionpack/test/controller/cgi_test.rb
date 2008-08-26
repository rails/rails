require 'abstract_unit'
require 'action_controller/cgi_process'

class BaseCgiTest < Test::Unit::TestCase
  def setup
    @request_hash = {
      "HTTP_MAX_FORWARDS" => "10",
      "SERVER_NAME" => "glu.ttono.us:8007",
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
    # some Nokia phone browsers omit the space after the semicolon separator.
    # some developers have grown accustomed to using comma in cookie values.
    @alt_cookie_fmt_request_hash = {"HTTP_COOKIE"=>"_session_id=c84ace847,96670c052c6ceb2451fb0f2;is_admin=yes"}
    @cgi = CGI.new
    @cgi.stubs(:env_table).returns(@request_hash)
    @request = ActionController::CgiRequest.new(@cgi)
  end

  def default_test; end

  private

  def set_content_data(data)
    @request.env['REQUEST_METHOD'] = 'POST'
    @request.env['CONTENT_LENGTH'] = data.length
    @request.env['CONTENT_TYPE'] = 'application/x-www-form-urlencoded; charset=utf-8'
    @request.env['RAW_POST_DATA'] = data
  end
end

class CgiRequestTest < BaseCgiTest
  def test_proxy_request
    assert_equal 'glu.ttono.us', @request.host_with_port
  end

  def test_http_host
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash['HTTP_HOST'] = "rubyonrails.org:8080"
    assert_equal "rubyonrails.org:8080", @request.host_with_port

    @request_hash['HTTP_X_FORWARDED_HOST'] = "www.firsthost.org, www.secondhost.org"
    assert_equal "www.secondhost.org", @request.host(true)
  end

  def test_http_host_with_default_port_overrides_server_port
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash['HTTP_HOST'] = "rubyonrails.org"
    assert_equal "rubyonrails.org", @request.host_with_port
  end

  def test_host_with_port_defaults_to_server_name_if_no_host_headers
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash.delete "HTTP_HOST"
    assert_equal "glu.ttono.us:8007", @request.host_with_port
  end

  def test_host_with_port_falls_back_to_server_addr_if_necessary
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash.delete "HTTP_HOST"
    @request_hash.delete "SERVER_NAME"
    assert_equal "207.7.108.53:8007", @request.host_with_port
  end

  def test_host_with_port_if_http_standard_port_is_specified
    @request_hash['HTTP_X_FORWARDED_HOST'] = "glu.ttono.us:80"
    assert_equal "glu.ttono.us", @request.host_with_port
  end

  def test_host_with_port_if_https_standard_port_is_specified
    @request_hash['HTTP_X_FORWARDED_PROTO'] = "https"
    @request_hash['HTTP_X_FORWARDED_HOST'] = "glu.ttono.us:443"
    assert_equal "glu.ttono.us", @request.host_with_port
  end

  def test_host_if_ipv6_reference
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash['HTTP_HOST'] = "[2001:1234:5678:9abc:def0::dead:beef]"
    assert_equal "[2001:1234:5678:9abc:def0::dead:beef]", @request.host
  end

  def test_host_if_ipv6_reference_with_port
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash['HTTP_HOST'] = "[2001:1234:5678:9abc:def0::dead:beef]:8008"
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
    assert_equal "glu.ttono.us:8007", @request.server_name
    assert_equal 8007, @request.server_port
    assert_equal "HTTP/1.1", @request.server_protocol
    assert_equal "lighttpd", @request.server_software
  end

  def test_cookie_syntax_resilience
    cookies = CGI::Cookie::parse(@request_hash["HTTP_COOKIE"]);
    assert_equal ["c84ace84796670c052c6ceb2451fb0f2"], cookies["_session_id"], cookies.inspect
    assert_equal ["yes"], cookies["is_admin"], cookies.inspect

    alt_cookies = CGI::Cookie::parse(@alt_cookie_fmt_request_hash["HTTP_COOKIE"]);
    assert_equal ["c84ace847,96670c052c6ceb2451fb0f2"], alt_cookies["_session_id"], alt_cookies.inspect
    assert_equal ["yes"], alt_cookies["is_admin"], alt_cookies.inspect
  end
end

class CgiRequestParamsParsingTest < BaseCgiTest
  def test_doesnt_break_when_content_type_has_charset
    set_content_data 'flamenco=love'

    assert_equal({"flamenco"=> "love"}, @request.request_parameters)
  end

  def test_doesnt_interpret_request_uri_as_query_string_when_missing
    @request.env['REQUEST_URI'] = 'foo'
    assert_equal({}, @request.query_parameters)
  end
end

class CgiRequestContentTypeTest < BaseCgiTest
  def test_html_content_type_verification
    @request.env['CONTENT_TYPE'] = Mime::HTML.to_s
    assert @request.content_type.verify_request?
  end

  def test_xml_content_type_verification
    @request.env['CONTENT_TYPE'] = Mime::XML.to_s
    assert !@request.content_type.verify_request?
  end
end

class CgiRequestMethodTest < BaseCgiTest
  def test_get
    assert_equal :get, @request.request_method
  end

  def test_post
    @request.env['REQUEST_METHOD'] = 'POST'
    assert_equal :post, @request.request_method
  end

  def test_put
    set_content_data '_method=put'

    assert_equal :put, @request.request_method
  end

  def test_delete
    set_content_data '_method=delete'

    assert_equal :delete, @request.request_method
  end
end

class CgiRequestNeedsRewoundTest < BaseCgiTest
  def test_body_should_be_rewound
    data = 'foo'
    fake_cgi = Struct.new(:env_table, :query_string, :stdinput).new(@request_hash, '', StringIO.new(data))
    fake_cgi.env_table['CONTENT_LENGTH'] = data.length
    fake_cgi.env_table['CONTENT_TYPE'] = 'application/x-www-form-urlencoded; charset=utf-8'

    # Read the request body by parsing params.
    request = ActionController::CgiRequest.new(fake_cgi)
    request.request_parameters

    # Should have rewound the body.
    assert_equal 0, request.body.pos
  end
end

uses_mocha 'CGI Response' do
  class CgiResponseTest < BaseCgiTest
    def setup
      super
      @cgi.expects(:header).returns("HTTP/1.0 200 OK\nContent-Type: text/html\n")
      @response = ActionController::CgiResponse.new(@cgi)
      @output = StringIO.new('')
    end

    def test_simple_output
      @response.body = "Hello, World!"

      @response.out(@output)
      assert_equal "HTTP/1.0 200 OK\nContent-Type: text/html\nHello, World!", @output.string
    end

    def test_head_request
      @cgi.env_table['REQUEST_METHOD'] = 'HEAD'
      @response.body = "Hello, World!"

      @response.out(@output)
      assert_equal "HTTP/1.0 200 OK\nContent-Type: text/html\n", @output.string
    end

    def test_streaming_block
      @response.body = Proc.new do |response, output|
        5.times { |n| output.write(n) }
      end

      @response.out(@output)
      assert_equal "HTTP/1.0 200 OK\nContent-Type: text/html\n01234", @output.string
    end
  end
end
