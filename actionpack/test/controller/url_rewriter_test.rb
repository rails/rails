require 'abstract_unit'
require 'controller/fake_controllers'

ActionController::UrlRewriter

class UrlRewriterTests < ActionController::TestCase
  def setup
    @request = ActionController::TestRequest.new
    @params = {}
    @rewriter = ActionController::UrlRewriter.new(@request, @params)
  end

  def test_port
    assert_equal('http://test.host:1271/c/a/i',
      @rewriter.rewrite(:controller => 'c', :action => 'a', :id => 'i', :port => 1271)
    )
  end

  def test_protocol_with_and_without_separator
    assert_equal('https://test.host/c/a/i',
      @rewriter.rewrite(:protocol => 'https', :controller => 'c', :action => 'a', :id => 'i')
    )

    assert_equal('https://test.host/c/a/i',
      @rewriter.rewrite(:protocol => 'https://', :controller => 'c', :action => 'a', :id => 'i')
    )
  end

  def test_user_name_and_password
    assert_equal(
      'http://david:secret@test.host/c/a/i',
      @rewriter.rewrite(:user => "david", :password => "secret", :controller => 'c', :action => 'a', :id => 'i')
    )
  end

  def test_user_name_and_password_with_escape_codes
    assert_equal(
      'http://openid.aol.com%2Fnextangler:one+two%3F@test.host/c/a/i',
      @rewriter.rewrite(:user => "openid.aol.com/nextangler", :password => "one two?", :controller => 'c', :action => 'a', :id => 'i')
    )
  end

  def test_anchor
    assert_equal(
      'http://test.host/c/a/i#anchor',
      @rewriter.rewrite(:controller => 'c', :action => 'a', :id => 'i', :anchor => 'anchor')
    )
  end

  def test_anchor_should_call_to_param
    assert_equal(
      'http://test.host/c/a/i#anchor',
      @rewriter.rewrite(:controller => 'c', :action => 'a', :id => 'i', :anchor => Struct.new(:to_param).new('anchor'))
    )
  end

  def test_anchor_should_be_cgi_escaped
    assert_equal(
      'http://test.host/c/a/i#anc%2Fhor',
      @rewriter.rewrite(:controller => 'c', :action => 'a', :id => 'i', :anchor => Struct.new(:to_param).new('anc/hor'))
    )
  end

  def test_overwrite_params
    @params[:controller] = 'hi'
    @params[:action] = 'bye'
    @params[:id] = '2'

    assert_equal '/hi/hi/2', @rewriter.rewrite(:only_path => true, :overwrite_params => {:action => 'hi'})
    u = @rewriter.rewrite(:only_path => false, :overwrite_params => {:action => 'hi'})
    assert_match %r(/hi/hi/2$), u
  end

  def test_overwrite_removes_original
    @params[:controller] = 'search'
    @params[:action] = 'list'
    @params[:list_page] = 1

    assert_equal '/search/list?list_page=2', @rewriter.rewrite(:only_path => true, :overwrite_params => {"list_page" => 2})
    u = @rewriter.rewrite(:only_path => false, :overwrite_params => {:list_page => 2})
    assert_equal 'http://test.host/search/list?list_page=2', u
  end

  def test_to_str
    @params[:controller] = 'hi'
    @params[:action] = 'bye'
    @request.parameters[:id] = '2'

    assert_equal 'http://, test.host, /, hi, bye, {"id"=>"2"}', @rewriter.to_str
  end

  def test_trailing_slash
    options = {:controller => 'foo', :action => 'bar', :id => '3', :only_path => true}
    assert_equal '/foo/bar/3', @rewriter.rewrite(options)
    assert_equal '/foo/bar/3?query=string', @rewriter.rewrite(options.merge({:query => 'string'}))
    options.update({:trailing_slash => true})
    assert_equal '/foo/bar/3/', @rewriter.rewrite(options)
    options.update({:query => 'string'})
    assert_equal '/foo/bar/3/?query=string', @rewriter.rewrite(options)
  end
end

