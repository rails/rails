require 'abstract_unit'

class RequestTest < ActiveSupport::TestCase
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
    e = assert_raise(ActionDispatch::RemoteIp::IpSpoofAttackError) {
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
    request = stub_request 'HTTP_X_FORWARDED_FOR' => '1.1.1.1',
                           'HTTP_CLIENT_IP'       => '2.2.2.2',
                           :ip_spoofing_check => false
    assert_equal '2.2.2.2', request.remote_ip

    request = stub_request 'HTTP_X_FORWARDED_FOR' => '8.8.8.8, 9.9.9.9'
    assert_equal '9.9.9.9', request.remote_ip
  end

  test "remote ip with user specified trusted proxies" do
    @trusted_proxies = /^67\.205\.106\.73$/i

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

  test "port string" do
    request = stub_request 'HTTP_HOST' => 'www.example.org:80'
    assert_equal "", request.port_string

    request = stub_request 'HTTP_HOST' => 'www.example.org:8080'
    assert_equal ":8080", request.port_string
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
    [:get, :post, :put, :delete].each do |method|
      request = stub_request 'REQUEST_METHOD' => method.to_s.upcase
      assert_equal method.to_s.upcase, request.method
    end
  end

  test "Symbol forms of request methods via method_symbol" do
    [:get, :post, :put, :delete].each do |method|
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
    %w(GET OPTIONS PUT POST DELETE).each do |method|
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
    [:get, :put, :delete].each do |method|
      request = stub_request 'REQUEST_METHOD' => method.to_s.upcase,
        'action_dispatch.request.request_parameters' => { :_method => 'put' }
      assert_equal method.to_s.upcase, request.method
    end
  end

  test "head masquerading as get" do
    request = stub_request 'REQUEST_METHOD' => 'GET', "rack.methodoverride.original_method" => "HEAD"
    assert_equal "HEAD", request.method
    assert_equal "GET",  request.request_method
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

protected

  def stub_request(env = {})
    ip_spoofing_check = env.key?(:ip_spoofing_check) ? env.delete(:ip_spoofing_check) : true
    ip_app = ActionDispatch::RemoteIp.new(Proc.new { }, ip_spoofing_check, @trusted_proxies)
    ip_app.call(env)
    ActionDispatch::Request.new(env)
  end

  def with_set(*args)
    args
  end
end
