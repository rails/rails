require 'abstract_unit'

class RequestTest < ActiveSupport::TestCase
  def setup
    ActionController::Base.relative_url_root = nil
  end

  def teardown
    ActionController::Base.relative_url_root = nil
  end

  test "remote ip" do
    request = stub_request 'REMOTE_ADDR' => '1.2.3.4'
    assert_equal '1.2.3.4', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '1.2.3.4,3.4.5.6'
    assert_equal '1.2.3.4', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '1.2.3.4',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '1.2.3.4', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '127.0.0.1',
      'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '172.16.0.1,3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '192.168.0.1,3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '10.0.0.1,3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '10.0.0.1, 10.0.0.1, 3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '127.0.0.1,3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,192.168.0.1'
    assert_equal 'unknown', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '9.9.9.9, 3.4.5.6, 10.0.0.1, 172.31.4.4'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '1.1.1.1',
                           'HTTP_CLIENT_IP'       => '2.2.2.2'
    e = assert_raise(ActionController::ActionControllerError) {
      request.remote_ip
    }
    assert_match /IP spoofing attack/, e.message
    assert_match /HTTP_X_FORWARDED_FOR="1.1.1.1"/, e.message
    assert_match /HTTP_CLIENT_IP="2.2.2.2"/, e.message

    # turn IP Spoofing detection off.
    # This is useful for sites that are aimed at non-IP clients.  The typical
    # example is WAP.  Since the cellular network is not IP based, it's a
    # leap of faith to assume that their proxies are ever going to set the
    # HTTP_CLIENT_IP/HTTP_X_FORWARDED_FOR headers properly.
    ActionController::Base.ip_spoofing_check = false
    request = stub_request 'HTTP_X_FORWARDED_FOR' => '1.1.1.1',
                           'HTTP_CLIENT_IP'       => '2.2.2.2'
    assert_equal '2.2.2.2', request.remote_ip
    ActionController::Base.ip_spoofing_check = true

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '8.8.8.8, 9.9.9.9'
    assert_equal '9.9.9.9', request.remote_ip
  end

  test "remote ip with user specified trusted proxies" do
    ActionController::Base.trusted_proxies = /^67\.205\.106\.73$/i

    request = stub_request 'REMOTE_ADDR' => '67.205.106.73',
                           'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '172.16.0.1,67.205.106.73',
                           'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '67.205.106.73,172.16.0.1',
                           'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '67.205.106.74,172.16.0.1',
                           'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '67.205.106.74', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,67.205.106.73'
    assert_equal 'unknown', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '9.9.9.9, 3.4.5.6, 10.0.0.1, 67.205.106.73'
    assert_equal '3.4.5.6', request.remote_ip

    ActionController::Base.trusted_proxies = nil
  end

  test "domains" do
    request = stub_request 'HTTP_HOST' => 'www.rubyonrails.org'
    assert_equal "rubyonrails.org", request.domain

    request = stub_request 'HTTP_HOST' => "www.rubyonrails.co.uk"
    assert_equal "rubyonrails.co.uk", request.domain(2)

    request = stub_request 'HTTP_HOST' => "192.168.1.200"
    assert_nil request.domain

    request = stub_request 'HTTP_HOST' => "foo.192.168.1.200"
    assert_nil request.domain

    request = stub_request 'HTTP_HOST' => "192.168.1.200.com"
    assert_equal "200.com", request.domain
  end

  test "subdomains" do
    request = stub_request 'HTTP_HOST' => "www.rubyonrails.org"
    assert_equal %w( www ), request.subdomains

    request = stub_request 'HTTP_HOST' => "www.rubyonrails.co.uk"
    assert_equal %w( www ), request.subdomains(2)

    request = stub_request 'HTTP_HOST' => "dev.www.rubyonrails.co.uk"
    assert_equal %w( dev www ), request.subdomains(2)

    request = stub_request 'HTTP_HOST' => "foobar.foobar.com"
    assert_equal %w( foobar ), request.subdomains

    request = stub_request 'HTTP_HOST' => "192.168.1.200"
    assert_equal [], request.subdomains

    request = stub_request 'HTTP_HOST' => "foo.192.168.1.200"
    assert_equal [], request.subdomains

    request = stub_request 'HTTP_HOST' => "192.168.1.200.com"
    assert_equal %w( 192 168 1 ), request.subdomains

    request = stub_request 'HTTP_HOST' => nil
    assert_equal [], request.subdomains
  end

  test "port string" do
    request = stub_request 'HTTP_HOST' => 'www.example.org:80'
    assert_equal "", request.port_string

    request = stub_request 'HTTP_HOST' => 'www.example.org:8080'
    assert_equal ":8080", request.port_string
  end

  test "request uri" do
    request = stub_request 'REQUEST_URI' => "http://www.rubyonrails.org/path/of/some/uri?mapped=1"
    assert_equal "/path/of/some/uri?mapped=1", request.request_uri
    assert_equal "/path/of/some/uri",          request.path

    request = stub_request 'REQUEST_URI' => "http://www.rubyonrails.org/path/of/some/uri"
    assert_equal "/path/of/some/uri", request.request_uri
    assert_equal "/path/of/some/uri", request.path

    request = stub_request 'REQUEST_URI' => "/path/of/some/uri"
    assert_equal "/path/of/some/uri", request.request_uri
    assert_equal "/path/of/some/uri", request.path

    request = stub_request 'REQUEST_URI' => "/"
    assert_equal "/", request.request_uri
    assert_equal "/", request.path

    request = stub_request 'REQUEST_URI' => "/?m=b"
    assert_equal "/?m=b", request.request_uri
    assert_equal "/",     request.path

    request = stub_request 'REQUEST_URI' => "/", 'SCRIPT_NAME' => '/dispatch.cgi'
    assert_equal "/", request.request_uri
    assert_equal "/", request.path

    ActionController::Base.relative_url_root = "/hieraki"
    request = stub_request 'REQUEST_URI' => "/hieraki/", 'SCRIPT_NAME' => "/hieraki/dispatch.cgi"
    assert_equal "/hieraki/", request.request_uri
    assert_equal "/",         request.path
    ActionController::Base.relative_url_root = nil

    ActionController::Base.relative_url_root = "/collaboration/hieraki"
    request = stub_request 'REQUEST_URI' => "/collaboration/hieraki/books/edit/2",
      'SCRIPT_NAME' => "/collaboration/hieraki/dispatch.cgi"
    assert_equal "/collaboration/hieraki/books/edit/2", request.request_uri
    assert_equal "/books/edit/2",                       request.path
    ActionController::Base.relative_url_root = nil

    # The following tests are for when REQUEST_URI is not supplied (as in IIS)
    request = stub_request 'PATH_INFO'   => "/path/of/some/uri?mapped=1",
                           'SCRIPT_NAME' => nil,
                           'REQUEST_URI' => nil
    assert_equal "/path/of/some/uri?mapped=1", request.request_uri
    assert_equal "/path/of/some/uri",          request.path

    ActionController::Base.relative_url_root = '/path'
    request = stub_request 'PATH_INFO'   => "/path/of/some/uri?mapped=1",
                           'SCRIPT_NAME' => "/path/dispatch.rb",
                           'REQUEST_URI' => nil
    assert_equal "/path/of/some/uri?mapped=1", request.request_uri
    assert_equal "/of/some/uri",               request.path
    ActionController::Base.relative_url_root = nil

    request = stub_request 'PATH_INFO'   => "/path/of/some/uri",
                           'SCRIPT_NAME' => nil,
                           'REQUEST_URI' => nil
    assert_equal "/path/of/some/uri", request.request_uri
    assert_equal "/path/of/some/uri", request.path

    request = stub_request 'PATH_INFO' => '/', 'REQUEST_URI' => nil
    assert_equal "/", request.request_uri
    assert_equal "/", request.path

    request = stub_request 'PATH_INFO' => '/?m=b', 'REQUEST_URI' => nil
    assert_equal "/?m=b", request.request_uri
    assert_equal "/",     request.path

    request = stub_request 'PATH_INFO'   => "/",
                           'SCRIPT_NAME' => "/dispatch.cgi",
                           'REQUEST_URI' => nil
    assert_equal "/", request.request_uri
    assert_equal "/", request.path

    ActionController::Base.relative_url_root = '/hieraki'
    request = stub_request 'PATH_INFO'   => "/hieraki/",
                           'SCRIPT_NAME' => "/hieraki/dispatch.cgi",
                           'REQUEST_URI' => nil
    assert_equal "/hieraki/", request.request_uri
    assert_equal "/",         request.path
    ActionController::Base.relative_url_root = nil

    request = stub_request 'REQUEST_URI' => '/hieraki/dispatch.cgi'
    ActionController::Base.relative_url_root = '/hieraki'
    assert_equal "/dispatch.cgi", request.path
    ActionController::Base.relative_url_root = nil

    request = stub_request 'REQUEST_URI' => '/hieraki/dispatch.cgi'
    ActionController::Base.relative_url_root = '/foo'
    assert_equal "/hieraki/dispatch.cgi", request.path
    ActionController::Base.relative_url_root = nil

    # This test ensures that Rails uses REQUEST_URI over PATH_INFO
    ActionController::Base.relative_url_root = nil
    request = stub_request 'REQUEST_URI' => "/some/path",
                           'PATH_INFO'   => "/another/path",
                           'SCRIPT_NAME' => "/dispatch.cgi"
    assert_equal "/some/path", request.request_uri
    assert_equal "/some/path", request.path
  end


  test "host with default port" do
    request = stub_request 'HTTP_HOST' => 'rubyonrails.org:80'
    assert_equal "rubyonrails.org", request.host_with_port
  end

  test "host with non default port" do
    request = stub_request 'HTTP_HOST' => 'rubyonrails.org:81'
    assert_equal "rubyonrails.org:81", request.host_with_port
  end

  test "server software" do
    request = stub_request
    assert_equal nil, request.server_software

    request = stub_request 'SERVER_SOFTWARE' => 'Apache3.422'
    assert_equal 'apache', request.server_software

    request = stub_request 'SERVER_SOFTWARE' => 'lighttpd(1.1.4)'
    assert_equal 'lighttpd', request.server_software
  end

  test "xml http request" do
    request = stub_request

    assert !request.xml_http_request?
    assert !request.xhr?

    request = stub_request 'HTTP_X_REQUESTED_WITH' => 'DefinitelyNotAjax1.0'
    assert !request.xml_http_request?
    assert !request.xhr?

    request = stub_request 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
    assert request.xml_http_request?
    assert request.xhr?
  end

  test "reports ssl" do
    request = stub_request
    assert !request.ssl?

    request = stub_request 'HTTPS' => 'on'
    assert request.ssl?
  end

  test "reports ssl when proxied via lighttpd" do
    request = stub_request
    assert !request.ssl?

    request = stub_request 'HTTP_X_FORWARDED_PROTO' => 'https'
    assert request.ssl?
  end

  test "symbolized request methods" do
    [:get, :post, :put, :delete].each do |method|
      request = stub_request 'REQUEST_METHOD' => method.to_s.upcase
      assert_equal method, request.method
    end
  end

  test "invalid http method raises exception" do
    assert_raise(ActionController::UnknownHttpMethod) do
      request = stub_request 'REQUEST_METHOD' => 'RANDOM_METHOD'
      request.request_method
    end
  end

  test "allow method hacking on post" do
    [:get, :head, :options, :put, :post, :delete].each do |method|
      request = stub_request "REQUEST_METHOD" => method.to_s.upcase
      assert_equal(method == :head ? :get : method, request.method)
    end
  end

  test "invalid method hacking on post raises exception" do
    assert_raise(ActionController::UnknownHttpMethod) do
      request = stub_request "REQUEST_METHOD" => "_RANDOM_METHOD"
      request.request_method
    end
  end

  test "restrict method hacking" do
    [:get, :put, :delete].each do |method|
      request = stub_request 'REQUEST_METHOD' => method.to_s.upcase,
        'action_dispatch.request.request_parameters' => { :_method => 'put' }
      assert_equal method, request.method
    end
  end

  test "head masquerading as get" do
    request = stub_request 'REQUEST_METHOD' => 'HEAD'
    assert_equal :get, request.method
    assert request.get?
    assert request.head?
  end

  test "xml format" do
    request = stub_request
    request.expects(:parameters).at_least_once.returns({ :format => 'xml' })
    assert_equal Mime::XML, request.format
  end

  test "xhtml format" do
    request = stub_request
    request.expects(:parameters).at_least_once.returns({ :format => 'xhtml' })
    assert_equal Mime::HTML, request.format
  end

  test "txt format" do
    request = stub_request
    request.expects(:parameters).at_least_once.returns({ :format => 'txt' })
    assert_equal Mime::TEXT, request.format
  end

  test "XMLHttpRequest" do
    with_accept_header false do
      request = stub_request 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
      request.expects(:parameters).at_least_once.returns({})
      assert request.xhr?
      assert_equal Mime::JS, request.format
    end
  end

  test "content type" do
    request = stub_request 'CONTENT_TYPE' => 'text/html'
    assert_equal Mime::HTML, request.content_type
  end

  test "can override format with parameter" do
    request = stub_request
    request.expects(:parameters).at_least_once.returns({ :format => :txt })
    assert !request.format.xml?

    request = stub_request
    request.expects(:parameters).at_least_once.returns({ :format => :xml })
    assert request.format.xml?
  end

  test "no content type" do
    request = stub_request
    assert_equal nil, request.content_type
  end

  test "content type is XML" do
    request = stub_request 'CONTENT_TYPE' => 'application/xml'
    assert_equal Mime::XML, request.content_type
  end

  test "content type with charset" do
    request = stub_request 'CONTENT_TYPE' => 'application/xml; charset=UTF-8'
    assert_equal Mime::XML, request.content_type
  end

  test "user agent" do
    request = stub_request 'HTTP_USER_AGENT' => 'TestAgent'
    assert_equal 'TestAgent', request.user_agent
  end

  test "parameters" do
    request = stub_request
    request.stubs(:request_parameters).returns({ "foo" => 1 })
    request.stubs(:query_parameters).returns({ "bar" => 2 })

    assert_equal({"foo" => 1, "bar" => 2}, request.parameters)
    assert_equal({"foo" => 1}, request.request_parameters)
    assert_equal({"bar" => 2}, request.query_parameters)
  end

  test "formats with accept header" do
    with_accept_header true do
      request = stub_request 'HTTP_ACCEPT' => 'text/html'
      request.expects(:parameters).at_least_once.returns({})
      assert_equal [ Mime::HTML ], request.formats

      request = stub_request 'CONTENT_TYPE' => 'application/xml; charset=UTF-8'
      request.expects(:parameters).at_least_once.returns({})
      assert_equal with_set(Mime::XML, Mime::HTML), request.formats
    end

    with_accept_header false do
      request = stub_request
      request.expects(:parameters).at_least_once.returns({ :format => :txt })
      assert_equal with_set(Mime::TEXT), request.formats
    end
  end

  test "negotiate_mime" do
    with_accept_header true do
      request = stub_request 'HTTP_ACCEPT' => 'text/html'
      request.expects(:parameters).at_least_once.returns({})

      assert_equal nil, request.negotiate_mime([Mime::XML, Mime::JSON])
      assert_equal Mime::HTML, request.negotiate_mime([Mime::XML, Mime::HTML])
      assert_equal Mime::HTML, request.negotiate_mime([Mime::XML, Mime::ALL])

      request = stub_request 'CONTENT_TYPE' => 'application/xml; charset=UTF-8'
      request.expects(:parameters).at_least_once.returns({})
      assert_equal Mime::XML, request.negotiate_mime([Mime::XML, Mime::CSV])
      assert_equal Mime::CSV, request.negotiate_mime([Mime::CSV, Mime::YAML])
    end
  end

protected

  def stub_request(env={})
    ActionDispatch::Request.new(env)
  end

  def with_set(*args)
    args + Mime::SET
  end

  def with_accept_header(value)
    ActionController::Base.use_accept_header, old = value, ActionController::Base.use_accept_header
    yield
  ensure
    ActionController::Base.use_accept_header = old
  end
end
