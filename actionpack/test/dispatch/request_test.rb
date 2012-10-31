require 'abstract_unit'

class RequestTest < ActiveSupport::TestCase

  def url_for(options = {})
    options.reverse_merge!(:host => 'www.example.com')
    ActionDispatch::Http::URL.url_for(options)
  end

  test "url_for class method" do
    e = assert_raise(ArgumentError) { url_for(:host => nil) }
    assert_match(/Please provide the :host parameter/, e.message)

    assert_equal '/books', url_for(:only_path => true, :path => '/books')

    assert_equal 'http://www.example.com',  url_for
    assert_equal 'http://api.example.com',  url_for(:subdomain => 'api')
    assert_equal 'http://example.com',      url_for(:subdomain => false)
    assert_equal 'http://www.ror.com',      url_for(:domain => 'ror.com')
    assert_equal 'http://api.ror.co.uk',    url_for(:host => 'www.ror.co.uk', :subdomain => 'api', :tld_length => 2)
    assert_equal 'http://www.example.com:8080',   url_for(:port => 8080)
    assert_equal 'https://www.example.com',       url_for(:protocol => 'https')
    assert_equal 'http://www.example.com/docs',   url_for(:path => '/docs')
    assert_equal 'http://www.example.com#signup', url_for(:anchor => 'signup')
    assert_equal 'http://www.example.com/',       url_for(:trailing_slash => true)
    assert_equal 'http://dhh:supersecret@www.example.com', url_for(:user => 'dhh', :password => 'supersecret')
    assert_equal 'http://www.example.com?search=books',    url_for(:params => { :search => 'books' })
  end

  test "remote ip" do
    request = stub_request 'REMOTE_ADDR' => '1.2.3.4'
    assert_equal '1.2.3.4', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '1.2.3.4,3.4.5.6'
    assert_equal '1.2.3.4', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '1.2.3.4',
                           'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '127.0.0.1',
                           'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '3.4.5.6,unknown'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '172.16.0.1,3.4.5.6'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '192.168.0.1,3.4.5.6'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '10.0.0.1,3.4.5.6'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '10.0.0.1, 10.0.0.1, 3.4.5.6'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '127.0.0.1,3.4.5.6'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,192.168.0.1'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '3.4.5.6, 9.9.9.9, 10.0.0.1, 172.31.4.4'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'not_ip_address'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '1.1.1.1',
                           'HTTP_CLIENT_IP'       => '2.2.2.2'
    e = assert_raise(ActionDispatch::RemoteIp::IpSpoofAttackError) {
      request.remote_ip
    }
    assert_match(/IP spoofing attack/, e.message)
    assert_match(/HTTP_X_FORWARDED_FOR="1.1.1.1"/, e.message)
    assert_match(/HTTP_CLIENT_IP="2.2.2.2"/, e.message)

    # turn IP Spoofing detection off.
    # This is useful for sites that are aimed at non-IP clients.  The typical
    # example is WAP.  Since the cellular network is not IP based, it's a
    # leap of faith to assume that their proxies are ever going to set the
    # HTTP_CLIENT_IP/HTTP_X_FORWARDED_FOR headers properly.
    request = stub_request 'HTTP_X_FORWARDED_FOR' => '1.1.1.1',
                           'HTTP_CLIENT_IP'       => '2.2.2.2',
                           :ip_spoofing_check => false
    assert_equal '2.2.2.2', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '9.9.9.9, 8.8.8.8'
    assert_equal '9.9.9.9', request.remote_ip
  end

  test "remote ip v6" do
    request = stub_request 'REMOTE_ADDR' => '2001:0db8:85a3:0000:0000:8a2e:0370:7334'
    assert_equal '2001:0db8:85a3:0000:0000:8a2e:0370:7334', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '2001:0db8:85a3:0000:0000:8a2e:0370:7334,fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal '2001:0db8:85a3:0000:0000:8a2e:0370:7334', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
                           'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '::1',
                           'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '::1,fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '::1,fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '::1,fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '::1, ::1, fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,::1'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '2001:0db8:85a3:0000:0000:8a2e:0370:7334, fe80:0000:0000:0000:0202:b3ff:fe1e:8329, ::1, fc00::'
    assert_equal '2001:0db8:85a3:0000:0000:8a2e:0370:7334', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'not_ip_address'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329',
                           'HTTP_CLIENT_IP'       => '2001:0db8:85a3:0000:0000:8a2e:0370:7334'
    e = assert_raise(ActionDispatch::RemoteIp::IpSpoofAttackError) {
      request.remote_ip
    }
    assert_match(/IP spoofing attack/, e.message)
    assert_match(/HTTP_X_FORWARDED_FOR="fe80:0000:0000:0000:0202:b3ff:fe1e:8329"/, e.message)
    assert_match(/HTTP_CLIENT_IP="2001:0db8:85a3:0000:0000:8a2e:0370:7334"/, e.message)

    # Turn IP Spoofing detection off.
    # This is useful for sites that are aimed at non-IP clients.  The typical
    # example is WAP.  Since the cellular network is not IP based, it's a
    # leap of faith to assume that their proxies are ever going to set the
    # HTTP_CLIENT_IP/HTTP_X_FORWARDED_FOR headers properly.
    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329',
                           'HTTP_CLIENT_IP'       => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
                           :ip_spoofing_check     => false
    assert_equal '2001:0db8:85a3:0000:0000:8a2e:0370:7334', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329, 2001:0db8:85a3:0000:0000:8a2e:0370:7334'
    assert_equal 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329', request.remote_ip
  end

  test "remote ip when the remote ip middleware returns nil" do
    request = stub_request 'REMOTE_ADDR' => '127.0.0.1'
    assert_equal '127.0.0.1', request.remote_ip
  end

  test "remote ip with user specified trusted proxies String" do
    @trusted_proxies = "67.205.106.73"

    request = stub_request 'REMOTE_ADDR' => '3.4.5.6',
                           'HTTP_X_FORWARDED_FOR' => '67.205.106.73'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '172.16.0.1,67.205.106.73',
                           'HTTP_X_FORWARDED_FOR' => '67.205.106.73'
    assert_equal '172.16.0.1', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => '67.205.106.73,3.4.5.6',
                           'HTTP_X_FORWARDED_FOR' => '67.205.106.73'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,67.205.106.73'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '3.4.5.6, 9.9.9.9, 10.0.0.1, 67.205.106.73'
    assert_equal '3.4.5.6', request.remote_ip
  end

  test "remote ip v6 with user specified trusted proxies String" do
    @trusted_proxies = 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329'

    request = stub_request 'REMOTE_ADDR' => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
                           'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal '2001:0db8:85a3:0000:0000:8a2e:0370:7334', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329,2001:0db8:85a3:0000:0000:8a2e:0370:7334',
                           'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal '2001:0db8:85a3:0000:0000:8a2e:0370:7334', request.remote_ip

    request = stub_request 'REMOTE_ADDR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329,::1',
                           'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'unknown,fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal nil, request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329,2001:0db8:85a3:0000:0000:8a2e:0370:7334'
    assert_equal nil, request.remote_ip
  end

  test "remote ip with user specified trusted proxies Regexp" do
    @trusted_proxies = /^67\.205\.106\.73$/i

    request = stub_request 'REMOTE_ADDR' => '67.205.106.73',
                           'HTTP_X_FORWARDED_FOR' => '3.4.5.6'
    assert_equal '3.4.5.6', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '67.205.106.73, 10.0.0.1, 9.9.9.9, 3.4.5.6'
    assert_equal nil, request.remote_ip
  end

  test "remote ip v6 with user specified trusted proxies Regexp" do
    @trusted_proxies = /^fe80:0000:0000:0000:0202:b3ff:fe1e:8329$/i

    request = stub_request 'REMOTE_ADDR' => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
                           'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329'
    assert_equal '2001:0db8:85a3:0000:0000:8a2e:0370:7334', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => 'fe80:0000:0000:0000:0202:b3ff:fe1e:8329, 2001:0db8:85a3:0000:0000:8a2e:0370:7334'
    assert_equal nil, request.remote_ip
  end

  test "domains" do
    request = stub_request 'HTTP_HOST' => 'www.rubyonrails.org'
    assert_equal "rubyonrails.org", request.domain

    request = stub_request 'HTTP_HOST' => "www.rubyonrails.co.uk"
    assert_equal "rubyonrails.co.uk", request.domain(2)

    request = stub_request 'HTTP_HOST' => "www.rubyonrails.co.uk", :tld_length => 2
    assert_equal "rubyonrails.co.uk", request.domain

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
    assert_equal "www", request.subdomain

    request = stub_request 'HTTP_HOST' => "www.rubyonrails.co.uk"
    assert_equal %w( www ), request.subdomains(2)
    assert_equal "www", request.subdomain(2)

    request = stub_request 'HTTP_HOST' => "dev.www.rubyonrails.co.uk"
    assert_equal %w( dev www ), request.subdomains(2)
    assert_equal "dev.www", request.subdomain(2)

    request = stub_request 'HTTP_HOST' => "dev.www.rubyonrails.co.uk", :tld_length => 2
    assert_equal %w( dev www ), request.subdomains
    assert_equal "dev.www", request.subdomain

    request = stub_request 'HTTP_HOST' => "foobar.foobar.com"
    assert_equal %w( foobar ), request.subdomains
    assert_equal "foobar", request.subdomain

    request = stub_request 'HTTP_HOST' => "192.168.1.200"
    assert_equal [], request.subdomains
    assert_equal "", request.subdomain

    request = stub_request 'HTTP_HOST' => "foo.192.168.1.200"
    assert_equal [], request.subdomains
    assert_equal "", request.subdomain

    request = stub_request 'HTTP_HOST' => "192.168.1.200.com"
    assert_equal %w( 192 168 1 ), request.subdomains
    assert_equal "192.168.1", request.subdomain

    request = stub_request 'HTTP_HOST' => nil
    assert_equal [], request.subdomains
    assert_equal "", request.subdomain
  end

  test "standard_port" do
    request = stub_request
    assert_equal 80, request.standard_port

    request = stub_request 'HTTPS' => 'on'
    assert_equal 443, request.standard_port
  end

  test "standard_port?" do
    request = stub_request
    assert !request.ssl?
    assert request.standard_port?

    request = stub_request 'HTTPS' => 'on'
    assert request.ssl?
    assert request.standard_port?

    request = stub_request 'HTTP_HOST' => 'www.example.org:8080'
    assert !request.ssl?
    assert !request.standard_port?

    request = stub_request 'HTTP_HOST' => 'www.example.org:8443', 'HTTPS' => 'on'
    assert request.ssl?
    assert !request.standard_port?
  end

  test "optional port" do
    request = stub_request 'HTTP_HOST' => 'www.example.org:80'
    assert_equal nil, request.optional_port

    request = stub_request 'HTTP_HOST' => 'www.example.org:8080'
    assert_equal 8080, request.optional_port
  end

  test "port string" do
    request = stub_request 'HTTP_HOST' => 'www.example.org:80'
    assert_equal '', request.port_string

    request = stub_request 'HTTP_HOST' => 'www.example.org:8080'
    assert_equal ':8080', request.port_string
  end

  test "full path" do
    request = stub_request 'SCRIPT_NAME' => '', 'PATH_INFO' => '/path/of/some/uri', 'QUERY_STRING' => 'mapped=1'
    assert_equal "/path/of/some/uri?mapped=1", request.fullpath
    assert_equal "/path/of/some/uri",          request.path_info

    request = stub_request 'SCRIPT_NAME' => '', 'PATH_INFO' => '/path/of/some/uri'
    assert_equal "/path/of/some/uri", request.fullpath
    assert_equal "/path/of/some/uri", request.path_info

    request = stub_request 'SCRIPT_NAME' => '', 'PATH_INFO' => '/'
    assert_equal "/", request.fullpath
    assert_equal "/", request.path_info

    request = stub_request 'SCRIPT_NAME' => '', 'PATH_INFO' => '/', 'QUERY_STRING' => 'm=b'
    assert_equal "/?m=b", request.fullpath
    assert_equal "/",     request.path_info

    request = stub_request 'SCRIPT_NAME' => '/hieraki', 'PATH_INFO' => '/'
    assert_equal "/hieraki/", request.fullpath
    assert_equal "/",         request.path_info

    request = stub_request 'SCRIPT_NAME' => '/collaboration/hieraki', 'PATH_INFO' => '/books/edit/2'
    assert_equal "/collaboration/hieraki/books/edit/2", request.fullpath
    assert_equal "/books/edit/2",                       request.path_info

    request = stub_request 'SCRIPT_NAME' => '/path', 'PATH_INFO' => '/of/some/uri', 'QUERY_STRING' => 'mapped=1'
    assert_equal "/path/of/some/uri?mapped=1", request.fullpath
    assert_equal "/of/some/uri",               request.path_info
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

  test "scheme returns https when proxied" do
    request = stub_request 'rack.url_scheme' => 'http'
    assert !request.ssl?
    assert_equal 'http', request.scheme

    request = stub_request 'rack.url_scheme' => 'http', 'HTTP_X_FORWARDED_PROTO' => 'https'
    assert request.ssl?
    assert_equal 'https', request.scheme
  end

  test "String request methods" do
    [:get, :post, :patch, :put, :delete].each do |method|
      request = stub_request 'REQUEST_METHOD' => method.to_s.upcase
      assert_equal method.to_s.upcase, request.method
    end
  end

  test "Symbol forms of request methods via method_symbol" do
    [:get, :post, :patch, :put, :delete].each do |method|
      request = stub_request 'REQUEST_METHOD' => method.to_s.upcase
      assert_equal method, request.method_symbol
    end
  end

  test "invalid http method raises exception" do
    assert_raise(ActionController::UnknownHttpMethod) do
      request = stub_request 'REQUEST_METHOD' => 'RANDOM_METHOD'
      request.request_method
    end
  end

  test "allow method hacking on post" do
    %w(GET OPTIONS PATCH PUT POST DELETE).each do |method|
      request = stub_request "REQUEST_METHOD" => method.to_s.upcase
      assert_equal(method == "HEAD" ? "GET" : method, request.method)
    end
  end

  test "invalid method hacking on post raises exception" do
    assert_raise(ActionController::UnknownHttpMethod) do
      request = stub_request "REQUEST_METHOD" => "_RANDOM_METHOD"
      request.request_method
    end
  end

  test "restrict method hacking" do
    [:get, :patch, :put, :delete].each do |method|
      request = stub_request 'REQUEST_METHOD' => method.to_s.upcase,
        'action_dispatch.request.request_parameters' => { :_method => 'put' }
      assert_equal method.to_s.upcase, request.method
    end
  end

  test "post masquerading as patch" do
    request = stub_request 'REQUEST_METHOD' => 'PATCH', "rack.methodoverride.original_method" => "POST"
    assert_equal "POST", request.method
    assert_equal "PATCH",  request.request_method
    assert request.patch?
  end

  test "post masquerading as put" do
    request = stub_request 'REQUEST_METHOD' => 'PUT', "rack.methodoverride.original_method" => "POST"
    assert_equal "POST", request.method
    assert_equal "PUT",  request.request_method
    assert request.put?
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
    request = stub_request 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest',
                           'HTTP_ACCEPT' =>
                             [Mime::JS, Mime::HTML, Mime::XML, 'text/xml', Mime::ALL].join(",")
    request.expects(:parameters).at_least_once.returns({})
    assert request.xhr?
    assert_equal Mime::JS, request.format
  end

  test "content type" do
    request = stub_request 'CONTENT_TYPE' => 'text/html'
    assert_equal Mime::HTML, request.content_mime_type
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
    assert_equal nil, request.content_mime_type
  end

  test "content type is XML" do
    request = stub_request 'CONTENT_TYPE' => 'application/xml'
    assert_equal Mime::XML, request.content_mime_type
  end

  test "content type with charset" do
    request = stub_request 'CONTENT_TYPE' => 'application/xml; charset=UTF-8'
    assert_equal Mime::XML, request.content_mime_type
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

  test "parameters still accessible after rack parse error" do
    mock_rack_env = { "QUERY_STRING" => "x[y]=1&x[y][][w]=2", "rack.input" => "foo" }
    request = nil
    request = stub_request(mock_rack_env)

    assert_raises(ActionController::BadRequest) do
      # rack will raise a TypeError when parsing this query string
      request.parameters
    end

    assert_equal({}, request.parameters)
  end

  test "we have access to the original exception" do
    mock_rack_env = { "QUERY_STRING" => "x[y]=1&x[y][][w]=2", "rack.input" => "foo" }
    request = nil
    request = stub_request(mock_rack_env)

    e = assert_raises(ActionController::BadRequest) do
      # rack will raise a TypeError when parsing this query string
      request.parameters
    end

    assert e.original_exception
    assert_equal e.original_exception.backtrace, e.backtrace
  end

  test "formats with accept header" do
    request = stub_request 'HTTP_ACCEPT' => 'text/html'
    request.expects(:parameters).at_least_once.returns({})
    assert_equal [ Mime::HTML ], request.formats

    request = stub_request 'CONTENT_TYPE' => 'application/xml; charset=UTF-8',
                           'HTTP_X_REQUESTED_WITH' => "XMLHttpRequest"
    request.expects(:parameters).at_least_once.returns({})
    assert_equal with_set(Mime::XML), request.formats

    request = stub_request
    request.expects(:parameters).at_least_once.returns({ :format => :txt })
    assert_equal with_set(Mime::TEXT), request.formats

    request = stub_request
    request.expects(:parameters).at_least_once.returns({ :format => :unknown })
    assert request.formats.empty?
  end

  test "formats with xhr request" do
    request = stub_request 'HTTP_X_REQUESTED_WITH' => "XMLHttpRequest"
    request.expects(:parameters).at_least_once.returns({})
    assert_equal [Mime::JS], request.formats
  end

  test "ignore_accept_header" do
    ActionDispatch::Request.ignore_accept_header = true

    begin
      request = stub_request 'HTTP_ACCEPT' => 'application/xml'
      request.expects(:parameters).at_least_once.returns({})
      assert_equal [ Mime::HTML ], request.formats

      request = stub_request 'HTTP_ACCEPT' => 'koz-asked/something-crazy'
      request.expects(:parameters).at_least_once.returns({})
      assert_equal [ Mime::HTML ], request.formats

      request = stub_request 'HTTP_ACCEPT' => '*/*;q=0.1'
      request.expects(:parameters).at_least_once.returns({})
      assert_equal [ Mime::HTML ], request.formats

      request = stub_request 'HTTP_ACCEPT' => 'application/jxw'
      request.expects(:parameters).at_least_once.returns({})
      assert_equal [ Mime::HTML ], request.formats

      request = stub_request 'HTTP_ACCEPT' => 'application/xml',
                             'HTTP_X_REQUESTED_WITH' => "XMLHttpRequest"
      request.expects(:parameters).at_least_once.returns({})
      assert_equal [ Mime::JS ], request.formats

      request = stub_request 'HTTP_ACCEPT' => 'application/xml',
                             'HTTP_X_REQUESTED_WITH' => "XMLHttpRequest"
      request.expects(:parameters).at_least_once.returns({:format => :json})
      assert_equal [ Mime::JSON ], request.formats
    ensure
      ActionDispatch::Request.ignore_accept_header = false
    end
  end

  test "negotiate_mime" do
    request = stub_request 'HTTP_ACCEPT' => 'text/html',
                           'HTTP_X_REQUESTED_WITH' => "XMLHttpRequest"

    request.expects(:parameters).at_least_once.returns({})

    assert_equal nil, request.negotiate_mime([Mime::XML, Mime::JSON])
    assert_equal Mime::HTML, request.negotiate_mime([Mime::XML, Mime::HTML])
    assert_equal Mime::HTML, request.negotiate_mime([Mime::XML, Mime::ALL])

    request = stub_request 'CONTENT_TYPE' => 'application/xml; charset=UTF-8',
                           'HTTP_X_REQUESTED_WITH' => "XMLHttpRequest"
    request.expects(:parameters).at_least_once.returns({})
    assert_equal Mime::XML, request.negotiate_mime([Mime::XML, Mime::CSV])
  end

  test "process parameter filter" do
    test_hashes = [
    [{'foo'=>'bar'},{'foo'=>'bar'},%w'food'],
    [{'foo'=>'bar'},{'foo'=>'[FILTERED]'},%w'foo'],
    [{'foo'=>'bar', 'bar'=>'foo'},{'foo'=>'[FILTERED]', 'bar'=>'foo'},%w'foo baz'],
    [{'foo'=>'bar', 'baz'=>'foo'},{'foo'=>'[FILTERED]', 'baz'=>'[FILTERED]'},%w'foo baz'],
    [{'bar'=>{'foo'=>'bar','bar'=>'foo'}},{'bar'=>{'foo'=>'[FILTERED]','bar'=>'foo'}},%w'fo'],
    [{'foo'=>{'foo'=>'bar','bar'=>'foo'}},{'foo'=>'[FILTERED]'},%w'f banana'],
    [{'baz'=>[{'foo'=>'baz'}, "1"]}, {'baz'=>[{'foo'=>'[FILTERED]'}, "1"]}, [/foo/]]]

    test_hashes.each do |before_filter, after_filter, filter_words|
      parameter_filter = ActionDispatch::Http::ParameterFilter.new(filter_words)
      assert_equal after_filter, parameter_filter.filter(before_filter)

      filter_words << 'blah'
      filter_words << lambda { |key, value|
        value.reverse! if key =~ /bargain/
      }

      parameter_filter = ActionDispatch::Http::ParameterFilter.new(filter_words)
      before_filter['barg'] = {'bargain'=>'gain', 'blah'=>'bar', 'bar'=>{'bargain'=>{'blah'=>'foo'}}}
      after_filter['barg']  = {'bargain'=>'niag', 'blah'=>'[FILTERED]', 'bar'=>{'bargain'=>{'blah'=>'[FILTERED]'}}}

      assert_equal after_filter, parameter_filter.filter(before_filter)
    end
  end

  test "filtered_parameters returns params filtered" do
    request = stub_request('action_dispatch.request.parameters' =>
      { 'lifo' => 'Pratik', 'amount' => '420', 'step' => '1' },
      'action_dispatch.parameter_filter' => [:lifo, :amount])

    params = request.filtered_parameters
    assert_equal "[FILTERED]", params["lifo"]
    assert_equal "[FILTERED]", params["amount"]
    assert_equal "1", params["step"]
  end

  test "filtered_env filters env as a whole" do
    request = stub_request('action_dispatch.request.parameters' =>
      { 'amount' => '420', 'step' => '1' }, "RAW_POST_DATA" => "yada yada",
      'action_dispatch.parameter_filter' => [:lifo, :amount])

    request = stub_request(request.filtered_env)

    assert_equal "[FILTERED]", request.raw_post
    assert_equal "[FILTERED]", request.params["amount"]
    assert_equal "1", request.params["step"]
  end

  test "filtered_path returns path with filtered query string" do
    %w(; &).each do |sep|
      request = stub_request('QUERY_STRING' => %w(username=sikachu secret=bd4f21f api_key=b1bc3b3cd352f68d79d7).join(sep),
        'PATH_INFO' => '/authenticate',
        'action_dispatch.parameter_filter' => [:secret, :api_key])

      path = request.filtered_path
      assert_equal %w(/authenticate?username=sikachu secret=[FILTERED] api_key=[FILTERED]).join(sep), path
    end
  end

  test "filtered_path should not unescape a genuine '[FILTERED]' value" do
    request = stub_request('QUERY_STRING' => "secret=bd4f21f&genuine=%5BFILTERED%5D",
      'PATH_INFO' => '/authenticate',
      'action_dispatch.parameter_filter' => [:secret])

    path = request.filtered_path
    assert_equal "/authenticate?secret=[FILTERED]&genuine=%5BFILTERED%5D", path
  end

  test "filtered_path should preserve duplication of keys in query string" do
    request = stub_request('QUERY_STRING' => "username=sikachu&secret=bd4f21f&username=fxn",
      'PATH_INFO' => '/authenticate',
      'action_dispatch.parameter_filter' => [:secret])

    path = request.filtered_path
    assert_equal "/authenticate?username=sikachu&secret=[FILTERED]&username=fxn", path
  end

  test "filtered_path should ignore searchparts" do
    request = stub_request('QUERY_STRING' => "secret",
      'PATH_INFO' => '/authenticate',
      'action_dispatch.parameter_filter' => [:secret])

    path = request.filtered_path
    assert_equal "/authenticate?secret", path
  end

  test "original_fullpath returns ORIGINAL_FULLPATH" do
    request = stub_request('ORIGINAL_FULLPATH' => "/foo?bar")

    path = request.original_fullpath
    assert_equal "/foo?bar", path
  end

  test "original_url returns url built using ORIGINAL_FULLPATH" do
    request = stub_request('ORIGINAL_FULLPATH' => "/foo?bar",
                           'HTTP_HOST'         => "example.org",
                           'rack.url_scheme'   => "http")

    url = request.original_url
    assert_equal "http://example.org/foo?bar", url
  end

  test "original_fullpath returns fullpath if ORIGINAL_FULLPATH is not present" do
    request = stub_request('PATH_INFO'    => "/foo",
                           'QUERY_STRING' => "bar")

    path = request.original_fullpath
    assert_equal "/foo?bar", path
  end

  test "if_none_match_etags none" do
    request = stub_request

    assert_equal nil, request.if_none_match
    assert_equal [], request.if_none_match_etags
    assert !request.etag_matches?("foo")
    assert !request.etag_matches?(nil)
  end

  test "if_none_match_etags single" do
    header = 'the-etag'
    request = stub_request('HTTP_IF_NONE_MATCH' => header)

    assert_equal header, request.if_none_match
    assert_equal [header], request.if_none_match_etags
    assert request.etag_matches?("the-etag")
  end

  test "if_none_match_etags quoted single" do
    header = '"the-etag"'
    request = stub_request('HTTP_IF_NONE_MATCH' => header)

    assert_equal header, request.if_none_match
    assert_equal ['the-etag'], request.if_none_match_etags
    assert request.etag_matches?("the-etag")
  end

  test "if_none_match_etags multiple" do
    header = 'etag1, etag2, "third etag", "etag4"'
    expected = ['etag1', 'etag2', 'third etag', 'etag4']
    request = stub_request('HTTP_IF_NONE_MATCH' => header)

    assert_equal header, request.if_none_match
    assert_equal expected, request.if_none_match_etags
    expected.each do |etag|
      assert request.etag_matches?(etag), etag
    end
  end

protected

  def stub_request(env = {})
    ip_spoofing_check = env.key?(:ip_spoofing_check) ? env.delete(:ip_spoofing_check) : true
    @trusted_proxies ||= nil
    ip_app = ActionDispatch::RemoteIp.new(Proc.new { }, ip_spoofing_check, @trusted_proxies)
    tld_length = env.key?(:tld_length) ? env.delete(:tld_length) : 1
    ip_app.call(env)
    ActionDispatch::Http::URL.tld_length = tld_length
    ActionDispatch::Request.new(env)
  end

  def with_set(*args)
    args
  end
end
