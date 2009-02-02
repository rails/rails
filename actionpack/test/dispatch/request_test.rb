require 'abstract_unit'

class RequestTest < ActiveSupport::TestCase
  def setup
    ActionController::Base.relative_url_root = nil
    @request = ActionController::TestRequest.new
  end

  def teardown
    ActionController::Base.relative_url_root = nil
  end

  test "remote ip" do
    assert_equal '0.0.0.0', @request.remote_ip

    @request.remote_addr = '1.2.3.4'
    assert_equal '1.2.3.4', @request.remote_ip

    @request.remote_addr = '1.2.3.4,3.4.5.6'
    assert_equal '1.2.3.4', @request.remote_ip

    @request.env['HTTP_CLIENT_IP'] = '2.3.4.5'
    assert_equal '1.2.3.4', @request.remote_ip

    @request.remote_addr = '192.168.0.1'
    assert_equal '2.3.4.5', @request.remote_ip
    @request.env.delete 'HTTP_CLIENT_IP'

    @request.remote_addr = '1.2.3.4'
    @request.env['HTTP_X_FORWARDED_FOR'] = '3.4.5.6'
    assert_equal '1.2.3.4', @request.remote_ip

    @request.remote_addr = '127.0.0.1'
    @request.env['HTTP_X_FORWARDED_FOR'] = '3.4.5.6'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = 'unknown,3.4.5.6'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = '172.16.0.1,3.4.5.6'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = '192.168.0.1,3.4.5.6'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = '10.0.0.1,3.4.5.6'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = '10.0.0.1, 10.0.0.1, 3.4.5.6'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = '127.0.0.1,3.4.5.6'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = 'unknown,192.168.0.1'
    assert_equal 'unknown', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = '9.9.9.9, 3.4.5.6, 10.0.0.1, 172.31.4.4'
    assert_equal '3.4.5.6', @request.remote_ip

    @request.env['HTTP_CLIENT_IP'] = '8.8.8.8'
    e = assert_raises(ActionController::ActionControllerError) {
      @request.remote_ip
    }
    assert_match /IP spoofing attack/, e.message
    assert_match /HTTP_X_FORWARDED_FOR="9.9.9.9, 3.4.5.6, 10.0.0.1, 172.31.4.4"/, e.message
    assert_match /HTTP_CLIENT_IP="8.8.8.8"/, e.message

    # turn IP Spoofing detection off.
    # This is useful for sites that are aimed at non-IP clients.  The typical
    # example is WAP.  Since the cellular network is not IP based, it's a
    # leap of faith to assume that their proxies are ever going to set the
    # HTTP_CLIENT_IP/HTTP_X_FORWARDED_FOR headers properly.
    ActionController::Base.ip_spoofing_check = false
    assert_equal('8.8.8.8', @request.remote_ip)
    ActionController::Base.ip_spoofing_check = true

    @request.env['HTTP_X_FORWARDED_FOR'] = '8.8.8.8, 9.9.9.9'
    assert_equal '8.8.8.8', @request.remote_ip

    @request.env.delete 'HTTP_CLIENT_IP'
    @request.env.delete 'HTTP_X_FORWARDED_FOR'
  end

  test "domains" do
    @request.host = "www.rubyonrails.org"
    assert_equal "rubyonrails.org", @request.domain

    @request.host = "www.rubyonrails.co.uk"
    assert_equal "rubyonrails.co.uk", @request.domain(2)

    @request.host = "192.168.1.200"
    assert_nil @request.domain

    @request.host = "foo.192.168.1.200"
    assert_nil @request.domain

    @request.host = "192.168.1.200.com"
    assert_equal "200.com", @request.domain

    @request.host = nil
    assert_nil @request.domain
  end

  test "subdomains" do
    @request.host = "www.rubyonrails.org"
    assert_equal %w( www ), @request.subdomains

    @request.host = "www.rubyonrails.co.uk"
    assert_equal %w( www ), @request.subdomains(2)

    @request.host = "dev.www.rubyonrails.co.uk"
    assert_equal %w( dev www ), @request.subdomains(2)

    @request.host = "foobar.foobar.com"
    assert_equal %w( foobar ), @request.subdomains

    @request.host = "192.168.1.200"
    assert_equal [], @request.subdomains

    @request.host = "foo.192.168.1.200"
    assert_equal [], @request.subdomains

    @request.host = "192.168.1.200.com"
    assert_equal %w( 192 168 1 ), @request.subdomains

    @request.host = nil
    assert_equal [], @request.subdomains
  end

  test "port string" do
    @request.port = 80
    assert_equal "", @request.port_string

    @request.port = 8080
    assert_equal ":8080", @request.port_string
  end

  test "request uri" do
    @request.env['SERVER_SOFTWARE'] = 'Apache 42.342.3432'

    @request.set_REQUEST_URI "http://www.rubyonrails.org/path/of/some/uri?mapped=1"
    assert_equal "/path/of/some/uri?mapped=1", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.set_REQUEST_URI "http://www.rubyonrails.org/path/of/some/uri"
    assert_equal "/path/of/some/uri", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.set_REQUEST_URI "/path/of/some/uri"
    assert_equal "/path/of/some/uri", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.set_REQUEST_URI "/"
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path

    @request.set_REQUEST_URI "/?m=b"
    assert_equal "/?m=b", @request.request_uri
    assert_equal "/", @request.path

    @request.set_REQUEST_URI "/"
    @request.env['SCRIPT_NAME'] = "/dispatch.cgi"
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path

    ActionController::Base.relative_url_root = "/hieraki"
    @request.set_REQUEST_URI "/hieraki/"
    @request.env['SCRIPT_NAME'] = "/hieraki/dispatch.cgi"
    assert_equal "/hieraki/", @request.request_uri
    assert_equal "/", @request.path
    ActionController::Base.relative_url_root = nil

    ActionController::Base.relative_url_root = "/collaboration/hieraki"
    @request.set_REQUEST_URI "/collaboration/hieraki/books/edit/2"
    @request.env['SCRIPT_NAME'] = "/collaboration/hieraki/dispatch.cgi"
    assert_equal "/collaboration/hieraki/books/edit/2", @request.request_uri
    assert_equal "/books/edit/2", @request.path
    ActionController::Base.relative_url_root = nil

    # The following tests are for when REQUEST_URI is not supplied (as in IIS)
    @request.env['PATH_INFO'] = "/path/of/some/uri?mapped=1"
    @request.env['SCRIPT_NAME'] = nil #"/path/dispatch.rb"
    @request.set_REQUEST_URI nil
    assert_equal "/path/of/some/uri?mapped=1", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    ActionController::Base.relative_url_root = '/path'
    @request.env['PATH_INFO'] = "/path/of/some/uri?mapped=1"
    @request.env['SCRIPT_NAME'] = "/path/dispatch.rb"
    @request.set_REQUEST_URI nil
    assert_equal "/path/of/some/uri?mapped=1", @request.request_uri
    assert_equal "/of/some/uri", @request.path
    ActionController::Base.relative_url_root = nil

    @request.env['PATH_INFO'] = "/path/of/some/uri"
    @request.env['SCRIPT_NAME'] = nil
    @request.set_REQUEST_URI nil
    assert_equal "/path/of/some/uri", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.env['PATH_INFO'] = "/"
    @request.set_REQUEST_URI nil
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path

    @request.env['PATH_INFO'] = "/?m=b"
    @request.set_REQUEST_URI nil
    assert_equal "/?m=b", @request.request_uri
    assert_equal "/", @request.path

    @request.env['PATH_INFO'] = "/"
    @request.env['SCRIPT_NAME'] = "/dispatch.cgi"
    @request.set_REQUEST_URI nil
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path

    ActionController::Base.relative_url_root = '/hieraki'
    @request.env['PATH_INFO'] = "/hieraki/"
    @request.env['SCRIPT_NAME'] = "/hieraki/dispatch.cgi"
    @request.set_REQUEST_URI nil
    assert_equal "/hieraki/", @request.request_uri
    assert_equal "/", @request.path
    ActionController::Base.relative_url_root = nil

    @request.set_REQUEST_URI '/hieraki/dispatch.cgi'
    ActionController::Base.relative_url_root = '/hieraki'
    assert_equal "/dispatch.cgi", @request.path
    ActionController::Base.relative_url_root = nil

    @request.set_REQUEST_URI '/hieraki/dispatch.cgi'
    ActionController::Base.relative_url_root = '/foo'
    assert_equal "/hieraki/dispatch.cgi", @request.path
    ActionController::Base.relative_url_root = nil

    # This test ensures that Rails uses REQUEST_URI over PATH_INFO
    ActionController::Base.relative_url_root = nil
    @request.env['REQUEST_URI'] = "/some/path"
    @request.env['PATH_INFO'] = "/another/path"
    @request.env['SCRIPT_NAME'] = "/dispatch.cgi"
    assert_equal "/some/path", @request.request_uri
    assert_equal "/some/path", @request.path
  end

  test "host with default port" do
    @request.host = "rubyonrails.org"
    @request.port = 80
    assert_equal "rubyonrails.org", @request.host_with_port
  end

  test "host with non default port" do
    @request.host = "rubyonrails.org"
    @request.port = 81
    assert_equal "rubyonrails.org:81", @request.host_with_port
  end

  test "server software" do
    assert_equal nil, @request.server_software

    @request.env['SERVER_SOFTWARE'] = 'Apache3.422'
    assert_equal 'apache', @request.server_software

    @request.env['SERVER_SOFTWARE'] = 'lighttpd(1.1.4)'
    assert_equal 'lighttpd', @request.server_software
  end

  test "xml http request" do
    assert !@request.xml_http_request?
    assert !@request.xhr?

    @request.env['HTTP_X_REQUESTED_WITH'] = "DefinitelyNotAjax1.0"
    assert !@request.xml_http_request?
    assert !@request.xhr?

    @request.env['HTTP_X_REQUESTED_WITH'] = "XMLHttpRequest"
    assert @request.xml_http_request?
    assert @request.xhr?
  end

  test "reports ssl" do
    assert !@request.ssl?
    @request.env['HTTPS'] = 'on'
    assert @request.ssl?
  end

  test "reports ssl when proxied via lighttpd" do
    assert !@request.ssl?
    @request.env['HTTP_X_FORWARDED_PROTO'] = 'https'
    assert @request.ssl?
  end

  test "symbolized request methods" do
    [:get, :post, :put, :delete].each do |method|
      self.request_method = method
      assert_equal method, @request.method
    end
  end

  test "invalid http method raises exception" do
    assert_raises(ActionController::UnknownHttpMethod) do
      self.request_method = :random_method
      @request.request_method
    end
  end

  test "allow method hacking on post" do
    [:get, :head, :options, :put, :post, :delete].each do |method|
      self.request_method = method
      assert_equal(method == :head ? :get : method, @request.method)
    end
  end

  test "invalid method hacking on post raises exception" do
    assert_raises(ActionController::UnknownHttpMethod) do
      self.request_method = :_random_method
      @request.request_method
    end
  end

  test "restrict method hacking" do
    @request.instance_eval { @parameters = { :_method => 'put' } }
    [:get, :put, :delete].each do |method|
      self.request_method = method
      assert_equal method, @request.method
    end
  end

  test "head masquerading as get" do
    self.request_method = :head
    assert_equal :get, @request.method
    assert @request.get?
    assert @request.head?
  end

  test "xml format" do
    @request.instance_eval { @parameters = { :format => 'xml' } }
    assert_equal Mime::XML, @request.format
  end

  test "xhtml format" do
    @request.instance_eval { @parameters = { :format => 'xhtml' } }
    assert_equal Mime::HTML, @request.format
  end

  test "txt format" do
    @request.instance_eval { @parameters = { :format => 'txt' } }
    assert_equal Mime::TEXT, @request.format
  end

  test "nil format" do
    begin
      ActionController::Base.use_accept_header, old =
        false, ActionController::Base.use_accept_header

      @request.instance_eval { @parameters = {} }
      @request.env["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest"
      assert @request.xhr?
      assert_equal Mime::JS, @request.format

    ensure
      ActionController::Base.use_accept_header = old
    end
  end

  test "content type" do
    @request.env["CONTENT_TYPE"] = "text/html"
    assert_equal Mime::HTML, @request.content_type
  end

  test "format assignment should set format" do
    @request.instance_eval { self.format = :txt }
    assert !@request.format.xml?
    @request.instance_eval { self.format = :xml }
    assert @request.format.xml?
  end

  test "content no type" do
    assert_equal nil, @request.content_type
  end

  test "content type xml" do
    @request.env["CONTENT_TYPE"] = "application/xml"
    assert_equal Mime::XML, @request.content_type
  end

  test "content type with charset" do
    @request.env["CONTENT_TYPE"] = "application/xml; charset=UTF-8"
    assert_equal Mime::XML, @request.content_type
  end

  test "user agent" do
    assert_not_nil @request.user_agent
  end

  test "parameters" do
    @request.stubs(:request_parameters).returns({ "foo" => 1 })
    @request.stubs(:query_parameters).returns({ "bar" => 2 })

    assert_equal({"foo" => 1, "bar" => 2}, @request.parameters)
    assert_equal({"foo" => 1}, @request.request_parameters)
    assert_equal({"bar" => 2}, @request.query_parameters)
  end

  protected
    def request_method=(method)
      @request.env['REQUEST_METHOD'] = method.to_s.upcase
      @request.request_method = nil # Reset the ivar cache
    end
end
