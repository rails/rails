require File.dirname(__FILE__) + '/../abstract_unit'

class RequestTest < Test::Unit::TestCase
  def setup
    @request = ActionController::TestRequest.new
  end

  def test_remote_ip
    assert_equal '0.0.0.0', @request.remote_ip

    @request.remote_addr = '1.2.3.4'
    assert_equal '1.2.3.4', @request.remote_ip

    @request.env['HTTP_CLIENT_IP'] = '2.3.4.5'
    assert_equal '2.3.4.5', @request.remote_ip
    @request.env.delete 'HTTP_CLIENT_IP'

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

    @request.env['HTTP_X_FORWARDED_FOR'] = '127.0.0.1,3.4.5.6'
    assert_equal '127.0.0.1', @request.remote_ip

    @request.env['HTTP_X_FORWARDED_FOR'] = 'unknown,192.168.0.1'
    assert_equal '1.2.3.4', @request.remote_ip
    @request.env.delete 'HTTP_X_FORWARDED_FOR'
  end

  def test_domains
    @request.host = "www.rubyonrails.org"
    assert_equal "rubyonrails.org", @request.domain

    @request.host = "www.rubyonrails.co.uk"
    assert_equal "rubyonrails.co.uk", @request.domain(2)
    
    @request.host = "192.168.1.200"
    assert_nil @request.domain

    @request.host = nil
    assert_nil @request.domain
  end

  def test_subdomains
    @request.host = "www.rubyonrails.org"
    assert_equal %w( www ), @request.subdomains

    @request.host = "www.rubyonrails.co.uk"
    assert_equal %w( www ), @request.subdomains(2)

    @request.host = "dev.www.rubyonrails.co.uk"
    assert_equal %w( dev www ), @request.subdomains(2)

    @request.host = "foobar.foobar.com"
    assert_equal %w( foobar ), @request.subdomains

    @request.host = nil
    assert_equal [], @request.subdomains
  end
  
  def test_port_string
    @request.port = 80
    assert_equal "", @request.port_string

    @request.port = 8080
    assert_equal ":8080", @request.port_string
  end
  
  def test_relative_url_root
    @request.env['SCRIPT_NAME'] = "/hieraki/dispatch.cgi"
    @request.env['SERVER_SOFTWARE'] = 'lighttpd/1.2.3'
    assert_equal '', @request.relative_url_root, "relative_url_root should be disabled on lighttpd"

    @request.env['SERVER_SOFTWARE'] = 'apache/1.2.3 some random text'
      
    @request.env['SCRIPT_NAME'] = nil
    assert_equal "", @request.relative_url_root

    @request.env['SCRIPT_NAME'] = "/dispatch.cgi"
    assert_equal "", @request.relative_url_root

    @request.env['SCRIPT_NAME'] = "/myapp.rb"
    assert_equal "", @request.relative_url_root

    @request.relative_url_root = nil
    @request.env['SCRIPT_NAME'] = "/hieraki/dispatch.cgi"
    assert_equal "/hieraki", @request.relative_url_root

    @request.relative_url_root = nil
    @request.env['SCRIPT_NAME'] = "/collaboration/hieraki/dispatch.cgi"
    assert_equal "/collaboration/hieraki", @request.relative_url_root    
    
    # apache/scgi case
    @request.relative_url_root = nil
    @request.env['SCRIPT_NAME'] = "/collaboration/hieraki"
    assert_equal "/collaboration/hieraki", @request.relative_url_root    
  end
  
  def test_request_uri
    @request.env['SERVER_SOFTWARE'] = 'Apache 42.342.3432'
  
    @request.relative_url_root = nil
    @request.set_REQUEST_URI "http://www.rubyonrails.org/path/of/some/uri?mapped=1"
    assert_equal "/path/of/some/uri?mapped=1", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path
    
    @request.relative_url_root = nil
    @request.set_REQUEST_URI "http://www.rubyonrails.org/path/of/some/uri"
    assert_equal "/path/of/some/uri", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.relative_url_root = nil
    @request.set_REQUEST_URI "/path/of/some/uri"
    assert_equal "/path/of/some/uri", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.relative_url_root = nil
    @request.set_REQUEST_URI "/"
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path

    @request.relative_url_root = nil
    @request.set_REQUEST_URI "/?m=b"
    assert_equal "/?m=b", @request.request_uri
    assert_equal "/", @request.path
    
    @request.relative_url_root = nil
    @request.set_REQUEST_URI "/"
    @request.env['SCRIPT_NAME'] = "/dispatch.cgi"
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path    

    @request.relative_url_root = nil
    @request.set_REQUEST_URI "/hieraki/"
    @request.env['SCRIPT_NAME'] = "/hieraki/dispatch.cgi"
    assert_equal "/hieraki/", @request.request_uri
    assert_equal "/", @request.path    

    @request.relative_url_root = nil
    @request.set_REQUEST_URI "/collaboration/hieraki/books/edit/2"
    @request.env['SCRIPT_NAME'] = "/collaboration/hieraki/dispatch.cgi"
    assert_equal "/collaboration/hieraki/books/edit/2", @request.request_uri
    assert_equal "/books/edit/2", @request.path
  
    # The following tests are for when REQUEST_URI is not supplied (as in IIS)
    @request.relative_url_root = nil
    @request.set_REQUEST_URI nil
    @request.env['PATH_INFO'] = "/path/of/some/uri?mapped=1"
    @request.env['SCRIPT_NAME'] = nil #"/path/dispatch.rb"
    assert_equal "/path/of/some/uri?mapped=1", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.relative_url_root = nil
    @request.env['PATH_INFO'] = "/path/of/some/uri?mapped=1"
    @request.env['SCRIPT_NAME'] = "/path/dispatch.rb"
    assert_equal "/path/of/some/uri?mapped=1", @request.request_uri
    assert_equal "/of/some/uri", @request.path

    @request.relative_url_root = nil
    @request.env['PATH_INFO'] = "/path/of/some/uri"
    @request.env['SCRIPT_NAME'] = nil
    assert_equal "/path/of/some/uri", @request.request_uri
    assert_equal "/path/of/some/uri", @request.path

    @request.relative_url_root = nil
    @request.env['PATH_INFO'] = "/"
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path

    @request.relative_url_root = nil
    @request.env['PATH_INFO'] = "/?m=b"
    assert_equal "/?m=b", @request.request_uri
    assert_equal "/", @request.path
    
    @request.relative_url_root = nil
    @request.env['PATH_INFO'] = "/"
    @request.env['SCRIPT_NAME'] = "/dispatch.cgi"
    assert_equal "/", @request.request_uri
    assert_equal "/", @request.path    

    @request.relative_url_root = nil
    @request.env['PATH_INFO'] = "/hieraki/"
    @request.env['SCRIPT_NAME'] = "/hieraki/dispatch.cgi"
    assert_equal "/hieraki/", @request.request_uri
    assert_equal "/", @request.path    

    # This test ensures that Rails uses REQUEST_URI over PATH_INFO
    @request.relative_url_root = nil
    @request.env['REQUEST_URI'] = "/some/path"
    @request.env['PATH_INFO'] = "/another/path"
    @request.env['SCRIPT_NAME'] = "/dispatch.cgi"
    assert_equal "/some/path", @request.request_uri
    assert_equal "/some/path", @request.path
  end
  

  def test_host_with_port
    @request.host = "rubyonrails.org"
    @request.port = 80
    assert_equal "rubyonrails.org", @request.host_with_port
    
    @request.host = "rubyonrails.org"
    @request.port = 81
    assert_equal "rubyonrails.org:81", @request.host_with_port
  end
  
  def test_server_software
    assert_equal nil, @request.server_software
  
    @request.env['SERVER_SOFTWARE'] = 'Apache3.422'
    assert_equal 'apache', @request.server_software
    
    @request.env['SERVER_SOFTWARE'] = 'lighttpd(1.1.4)'
    assert_equal 'lighttpd', @request.server_software
  end
  
  def test_xml_http_request
    assert !@request.xml_http_request?
    assert !@request.xhr?
    
    @request.env['HTTP_X_REQUESTED_WITH'] = "DefinitelyNotAjax1.0"
    assert !@request.xml_http_request?
    assert !@request.xhr?
    
    @request.env['HTTP_X_REQUESTED_WITH'] = "XMLHttpRequest"
    assert @request.xml_http_request?
    assert @request.xhr?
  end
  
end
