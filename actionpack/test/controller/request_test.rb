require File.dirname(__FILE__) + '/../abstract_unit'

class RequestTest < Test::Unit::TestCase
  def setup
    @request = ActionController::TestRequest.new
  end

  def test_domains
    @request.host = "www.rubyonrails.org"
    assert_equal "rubyonrails.org", @request.domain

    @request.host = "www.rubyonrails.co.uk"
    assert_equal "rubyonrails.co.uk", @request.domain(2)
  end

  def test_subdomains
    @request.host = "www.rubyonrails.org"
    assert_equal %w( www ), @request.subdomains

    @request.host = "www.rubyonrails.co.uk"
    assert_equal %w( www ), @request.subdomains(2)

    @request.host = "dev.www.rubyonrails.co.uk"
    assert_equal %w( dev www ), @request.subdomains(2)
  end
  
  def test_port_string
    @request.port = 80
    assert_equal "", @request.port_string

    @request.port = 8080
    assert_equal ":8080", @request.port_string
  end
  
  def test_request_uri
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
  end

  def test_host_with_port
    @request.env['HTTP_HOST'] = "rubyonrails.org:8080"
    assert_equal "rubyonrails.org:8080", @request.host_with_port
    @request.env['HTTP_HOST'] = nil
    
    @request.host = "rubyonrails.org"
    @request.port = 80
    assert_equal "rubyonrails.org", @request.host_with_port
    
    @request.host = "rubyonrails.org"
    @request.port = 81
    assert_equal "rubyonrails.org:81", @request.host_with_port
  end
end