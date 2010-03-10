require 'abstract_unit'

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

    assert_deprecated /overwrite_params/ do
      assert_equal '/hi/hi/2', @rewriter.rewrite(:only_path => true, :overwrite_params => {:action => 'hi'})
      u = @rewriter.rewrite(:only_path => false, :overwrite_params => {:action => 'hi'})
      assert_match %r(/hi/hi/2$), u
    end
  end

  def test_overwrite_removes_original
    @params[:controller] = 'search'
    @params[:action] = 'list'
    @params[:list_page] = 1

    assert_deprecated /overwrite_params/ do
      assert_equal '/search/list?list_page=2', @rewriter.rewrite(:only_path => true, :overwrite_params => {"list_page" => 2})
      u = @rewriter.rewrite(:only_path => false, :overwrite_params => {:list_page => 2})
      assert_equal 'http://test.host/search/list?list_page=2', u
    end
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

class UrlWriterTests < ActionController::TestCase
  class W
    include ActionController::UrlWriter
  end

  def teardown
    W.default_url_options.clear
  end

  def add_host!
    W.default_url_options[:host] = 'www.basecamphq.com'
  end

  def test_exception_is_thrown_without_host
    assert_raise RuntimeError do
      W.new.url_for :controller => 'c', :action => 'a', :id => 'i'
    end
  end

  def test_anchor
    assert_equal('/c/a#anchor',
      W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :anchor => 'anchor')
    )
  end

  def test_anchor_should_call_to_param
    assert_equal('/c/a#anchor',
      W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :anchor => Struct.new(:to_param).new('anchor'))
    )
  end

  def test_anchor_should_be_cgi_escaped
    assert_equal('/c/a#anc%2Fhor',
      W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :anchor => Struct.new(:to_param).new('anc/hor'))
    )
  end

  def test_default_host
    add_host!
    assert_equal('http://www.basecamphq.com/c/a/i',
      W.new.url_for(:controller => 'c', :action => 'a', :id => 'i')
    )
  end

  def test_host_may_be_overridden
    add_host!
    assert_equal('http://37signals.basecamphq.com/c/a/i',
      W.new.url_for(:host => '37signals.basecamphq.com', :controller => 'c', :action => 'a', :id => 'i')
    )
  end

  def test_port
    add_host!
    assert_equal('http://www.basecamphq.com:3000/c/a/i',
      W.new.url_for(:controller => 'c', :action => 'a', :id => 'i', :port => 3000)
    )
  end

  def test_protocol
    add_host!
    assert_equal('https://www.basecamphq.com/c/a/i',
      W.new.url_for(:controller => 'c', :action => 'a', :id => 'i', :protocol => 'https')
    )
  end

  def test_protocol_with_and_without_separator
    add_host!
    assert_equal('https://www.basecamphq.com/c/a/i',
      W.new.url_for(:controller => 'c', :action => 'a', :id => 'i', :protocol => 'https')
    )
    assert_equal('https://www.basecamphq.com/c/a/i',
      W.new.url_for(:controller => 'c', :action => 'a', :id => 'i', :protocol => 'https://')
    )
  end

  def test_trailing_slash
    add_host!
    options = {:controller => 'foo', :trailing_slash => true, :action => 'bar', :id => '33'}
    assert_equal('http://www.basecamphq.com/foo/bar/33/', W.new.url_for(options) )
  end

  def test_trailing_slash_with_protocol
    add_host!
    options = { :trailing_slash => true,:protocol => 'https', :controller => 'foo', :action => 'bar', :id => '33'}
    assert_equal('https://www.basecamphq.com/foo/bar/33/', W.new.url_for(options) )
    assert_equal 'https://www.basecamphq.com/foo/bar/33/?query=string', W.new.url_for(options.merge({:query => 'string'}))
  end

  def test_trailing_slash_with_only_path
    options = {:controller => 'foo', :trailing_slash => true}
    assert_equal '/foo/', W.new.url_for(options.merge({:only_path => true}))
    options.update({:action => 'bar', :id => '33'})
    assert_equal '/foo/bar/33/', W.new.url_for(options.merge({:only_path => true}))
    assert_equal '/foo/bar/33/?query=string', W.new.url_for(options.merge({:query => 'string',:only_path => true}))
  end

  def test_trailing_slash_with_anchor
    options = {:trailing_slash => true, :controller => 'foo', :action => 'bar', :id => '33', :only_path => true, :anchor=> 'chapter7'}
    assert_equal '/foo/bar/33/#chapter7', W.new.url_for(options)
    assert_equal '/foo/bar/33/?query=string#chapter7', W.new.url_for(options.merge({:query => 'string'}))
  end

  def test_trailing_slash_with_params
    url = W.new.url_for(:trailing_slash => true, :only_path => true, :controller => 'cont', :action => 'act', :p1 => 'cafe', :p2 => 'link')
    params = extract_params(url)
    assert_equal params[0], { :p1 => 'cafe' }.to_query
    assert_equal params[1], { :p2 => 'link' }.to_query
  end

  def test_relative_url_root_is_respected
    orig_relative_url_root = ActionController::Base.relative_url_root
    ActionController::Base.relative_url_root = '/subdir'

    add_host!
    assert_equal('https://www.basecamphq.com/subdir/c/a/i',
      W.new.url_for(:controller => 'c', :action => 'a', :id => 'i', :protocol => 'https')
    )
  ensure
    ActionController::Base.relative_url_root = orig_relative_url_root
  end

  def test_named_routes
    ActionController::Routing::Routes.draw do |map|
      map.no_args '/this/is/verbose', :controller => 'home', :action => 'index'
      map.home '/home/sweet/home/:user', :controller => 'home', :action => 'index'
      map.connect ':controller/:action/:id'
    end

    # We need to create a new class in order to install the new named route.
    kls = Class.new { include ActionController::UrlWriter }
    controller = kls.new
    assert controller.respond_to?(:home_url)
    assert_equal 'http://www.basecamphq.com/home/sweet/home/again',
      controller.send(:home_url, :host => 'www.basecamphq.com', :user => 'again')

    assert_equal("/home/sweet/home/alabama", controller.send(:home_path, :user => 'alabama', :host => 'unused'))
    assert_equal("http://www.basecamphq.com/home/sweet/home/alabama", controller.send(:home_url, :user => 'alabama', :host => 'www.basecamphq.com'))
    assert_equal("http://www.basecamphq.com/this/is/verbose", controller.send(:no_args_url, :host=>'www.basecamphq.com'))
  ensure
    ActionController::Routing::Routes.load!
  end

  def test_relative_url_root_is_respected_for_named_routes
    orig_relative_url_root = ActionController::Base.relative_url_root
    ActionController::Base.relative_url_root = '/subdir'

    ActionController::Routing::Routes.draw do |map|
      map.home '/home/sweet/home/:user', :controller => 'home', :action => 'index'
    end

    kls = Class.new { include ActionController::UrlWriter }
    controller = kls.new

    assert_equal 'http://www.basecamphq.com/subdir/home/sweet/home/again',
      controller.send(:home_url, :host => 'www.basecamphq.com', :user => 'again')
  ensure
    ActionController::Routing::Routes.load!
    ActionController::Base.relative_url_root = orig_relative_url_root
  end

  def test_only_path
    ActionController::Routing::Routes.draw do |map|
      map.home '/home/sweet/home/:user', :controller => 'home', :action => 'index'
      map.connect ':controller/:action/:id'
    end

    # We need to create a new class in order to install the new named route.
    kls = Class.new { include ActionController::UrlWriter }
    controller = kls.new
    assert controller.respond_to?(:home_url)
    assert_equal '/brave/new/world',
      controller.send(:url_for, :controller => 'brave', :action => 'new', :id => 'world', :only_path => true)

    assert_equal("/home/sweet/home/alabama", controller.send(:home_url, :user => 'alabama', :host => 'unused', :only_path => true))
    assert_equal("/home/sweet/home/alabama", controller.send(:home_path, 'alabama'))
  ensure
    ActionController::Routing::Routes.load!
  end

  def test_one_parameter
    assert_equal('/c/a?param=val',
      W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :param => 'val')
    )
  end

  def test_two_parameters
    url = W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :p1 => 'X1', :p2 => 'Y2')
    params = extract_params(url)
    assert_equal params[0], { :p1 => 'X1' }.to_query
    assert_equal params[1], { :p2 => 'Y2' }.to_query
  end

  def test_hash_parameter
    url = W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :query => {:name => 'Bob', :category => 'prof'})
    params = extract_params(url)
    assert_equal params[0], { 'query[category]' => 'prof' }.to_query
    assert_equal params[1], { 'query[name]'     => 'Bob'  }.to_query
  end

  def test_array_parameter
    url = W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :query => ['Bob', 'prof'])
    params = extract_params(url)
    assert_equal params[0], { 'query[]' => 'Bob'  }.to_query
    assert_equal params[1], { 'query[]' => 'prof' }.to_query
  end

  def test_hash_recursive_parameters
    url = W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :query => {:person => {:name => 'Bob', :position => 'prof'}, :hobby => 'piercing'})
    params = extract_params(url)
    assert_equal params[0], { 'query[hobby]'            => 'piercing' }.to_query
    assert_equal params[1], { 'query[person][name]'     => 'Bob'      }.to_query
    assert_equal params[2], { 'query[person][position]' => 'prof'     }.to_query
  end

  def test_hash_recursive_and_array_parameters
    url = W.new.url_for(:only_path => true, :controller => 'c', :action => 'a', :id => 101, :query => {:person => {:name => 'Bob', :position => ['prof', 'art director']}, :hobby => 'piercing'})
    assert_match %r(^/c/a/101), url
    params = extract_params(url)
    assert_equal params[0], { 'query[hobby]'              => 'piercing'     }.to_query
    assert_equal params[1], { 'query[person][name]'       => 'Bob'          }.to_query
    assert_equal params[2], { 'query[person][position][]' => 'prof'         }.to_query
    assert_equal params[3], { 'query[person][position][]' => 'art director' }.to_query
  end

  def test_path_generation_for_symbol_parameter_keys
    assert_generates("/image", :controller=> :image)
  end

  def test_named_routes_with_nil_keys
    ActionController::Routing::Routes.clear!
    ActionController::Routing::Routes.draw do |map|
      map.main '', :controller => 'posts', :format => nil
      map.resources :posts
      map.connect ':controller/:action/:id'
    end
    # We need to create a new class in order to install the new named route.
    kls = Class.new { include ActionController::UrlWriter }
    kls.default_url_options[:host] = 'www.basecamphq.com'

    controller = kls.new
    params = {:action => :index, :controller => :posts, :format => :xml}
    assert_equal("http://www.basecamphq.com/posts.xml", controller.send(:url_for, params))
    params[:format] = nil
    assert_equal("http://www.basecamphq.com/", controller.send(:url_for, params))
  ensure
    ActionController::Routing::Routes.load!
  end

  def test_formatted_url_methods_are_deprecated
    ActionController::Routing::Routes.draw do |map|
      map.resources :posts
    end
    # We need to create a new class in order to install the new named route.
    kls = Class.new { include ActionController::UrlWriter }
    controller = kls.new
    params = {:id => 1, :format => :xml}
    assert_deprecated do
      assert_equal("/posts/1.xml", controller.send(:formatted_post_path, params))    
    end
    assert_deprecated do
      assert_equal("/posts/1.xml", controller.send(:formatted_post_path, 1, :xml))    
    end
  ensure
    ActionController::Routing::Routes.load!
  end

  def test_multiple_includes_maintain_distinct_options
    first_class = Class.new { include ActionController::UrlWriter }
    second_class = Class.new { include ActionController::UrlWriter }

    first_host, second_host = 'firsthost.com', 'secondhost.com'

    first_class.default_url_options[:host] = first_host
    second_class.default_url_options[:host] = second_host

    assert_equal first_class.default_url_options[:host], first_host
    assert_equal second_class.default_url_options[:host], second_host
  end

  private
    def extract_params(url)
      url.split('?', 2).last.split('&')
    end
end
