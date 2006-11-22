require File.dirname(__FILE__) + '/../abstract_unit'

class UrlRewriterTests < Test::Unit::TestCase
  def setup
    @request = ActionController::TestRequest.new
    @params = {}
    @rewriter = ActionController::UrlRewriter.new(@request, @params)
  end 

  def test_overwrite_params
    @params[:controller] = 'hi'
    @params[:action] = 'bye'
    @params[:id] = '2'

    assert_equal '/hi/hi/2', @rewriter.rewrite(:only_path => true, :overwrite_params => {:action => 'hi'})
    u = @rewriter.rewrite(:only_path => false, :overwrite_params => {:action => 'hi'})
    assert_match %r(/hi/hi/2$), u
  end
  

  private
    def split_query_string(str)
      [str[0].chr] + str[1..-1].split(/&/).sort
    end
  
    def assert_query_equal(q1, q2)
      assert_equal(split_query_string(q1), split_query_string(q2))
    end
end

class UrlWriterTests < Test::Unit::TestCase
  
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
    assert_raises RuntimeError do
      W.new.url_for :controller => 'c', :action => 'a', :id => 'i'
    end
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
  
  def test_named_route
    ActionController::Routing::Routes.draw do |map|
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
  ensure
    ActionController::Routing::Routes.load!
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
  ensure
    ActionController::Routing::Routes.load!
  end
  
end
