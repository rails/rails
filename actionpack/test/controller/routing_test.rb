# encoding: utf-8
require 'abstract_unit'
require 'controller/fake_controllers'
require 'active_support/dependencies'

class MilestonesController < ActionController::Base
  def index() head :ok end
  alias_method :show, :index
  def rescue_action(e) raise e end
end

ROUTING = ActionController::Routing

# See RFC 3986, section 3.3 for allowed path characters.
class UriReservedCharactersRoutingTest < Test::Unit::TestCase
  def setup
    @set = ActionController::Routing::RouteSet.new
    @set.draw do |map|
      map.connect ':controller/:action/:variable/*additional'
    end

    safe, unsafe = %w(: @ & = + $ , ;), %w(^ ? # [ ])
    hex = unsafe.map { |char| '%' + char.unpack('H2').first.upcase }

    @segment = "#{safe.join}#{unsafe.join}".freeze
    @escaped = "#{safe.join}#{hex.join}".freeze
  end

  def test_route_generation_escapes_unsafe_path_characters
    @set.generate(:controller => "content", :action => "act#{@segment}ion", :variable => "variable", :additional => "foo")
    assert_equal "/content/act#{@escaped}ion/var#{@escaped}iable/add#{@escaped}itional-1/add#{@escaped}itional-2",
      @set.generate(:controller => "content",
                    :action => "act#{@segment}ion",
                    :variable => "var#{@segment}iable",
                    :additional => ["add#{@segment}itional-1", "add#{@segment}itional-2"])
  end

  def test_route_recognition_unescapes_path_components
    options = { :controller => "content",
                :action => "act#{@segment}ion",
                :variable => "var#{@segment}iable",
                :additional => ["add#{@segment}itional-1", "add#{@segment}itional-2"] }
    assert_equal options, @set.recognize_path("/content/act#{@escaped}ion/var#{@escaped}iable/add#{@escaped}itional-1/add#{@escaped}itional-2")
  end

  def test_route_generation_allows_passing_non_string_values_to_generated_helper
    assert_equal "/content/action/variable/1/2", @set.generate(:controller => "content",
                                                                  :action => "action",
                                                                  :variable => "variable",
                                                                  :additional => [1, 2])
  end
end

class MockController
  def self.build(helpers)
    Class.new do
      def url_for(options)
        options[:protocol] ||= "http"
        options[:host] ||= "test.host"

        super(options)
      end

      include helpers
    end
  end
end

class LegacyRouteSetTests < Test::Unit::TestCase
  attr_reader :rs

  def setup
    @rs = ::ActionController::Routing::RouteSet.new
  end

  def teardown
    @rs.clear!
  end

  def test_default_setup
    @rs.draw {|m| m.connect ':controller/:action/:id' }
    assert_equal({:controller => "content", :action => 'index'}, rs.recognize_path("/content"))
    assert_equal({:controller => "content", :action => 'list'}, rs.recognize_path("/content/list"))
    assert_equal({:controller => "content", :action => 'show', :id => '10'}, rs.recognize_path("/content/show/10"))

    assert_equal({:controller => "admin/user", :action => 'show', :id => '10'}, rs.recognize_path("/admin/user/show/10"))

    assert_equal '/admin/user/show/10', rs.generate(:controller => 'admin/user', :action => 'show', :id => 10)

    assert_equal '/admin/user/show', rs.generate({:action => 'show'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
    assert_equal '/admin/user/list/10', rs.generate({}, {:controller => 'admin/user', :action => 'list', :id => '10'})

    assert_equal '/admin/stuff', rs.generate({:controller => 'stuff'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
    assert_equal '/stuff', rs.generate({:controller => '/stuff'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
  end

  def test_ignores_leading_slash
    @rs.clear!
    @rs.draw {|m| m.connect '/:controller/:action/:id'}
    test_default_setup
  end

  def test_time_recognition
    # We create many routes to make situation more realistic
    @rs = ::ActionController::Routing::RouteSet.new
    @rs.draw { |map|
      map.frontpage '', :controller => 'search', :action => 'new'
      map.resources :videos do |video|
        video.resources :comments
        video.resource  :file,      :controller => 'video_file'
        video.resource  :share,     :controller => 'video_shares'
        video.resource  :abuse,     :controller => 'video_abuses'
      end
      map.resources :abuses, :controller => 'video_abuses'
      map.resources :video_uploads
      map.resources :video_visits

      map.resources :users do |user|
        user.resource  :settings
        user.resources :videos
      end
      map.resources :channels do |channel|
        channel.resources :videos, :controller => 'channel_videos'
      end
      map.resource  :session
      map.resource  :lost_password
      map.search    'search', :controller => 'search'
      map.resources :pages
      map.connect ':controller/:action/:id'
    }
  end

  def test_route_with_colon_first
    rs.draw do |map|
      map.connect '/:controller/:action/:id', :action => 'index', :id => nil
      map.connect ':url', :controller => 'tiny_url', :action => 'translate'
    end
  end

  def test_route_with_regexp_for_controller
    rs.draw do |map|
      map.connect ':controller/:admintoken/:action/:id', :controller => /admin\/.+/
      map.connect ':controller/:action/:id'
    end
    assert_equal({:controller => "admin/user", :admintoken => "foo", :action => "index"},
        rs.recognize_path("/admin/user/foo"))
    assert_equal({:controller => "content", :action => "foo"}, rs.recognize_path("/content/foo"))
    assert_equal '/admin/user/foo', rs.generate(:controller => "admin/user", :admintoken => "foo", :action => "index")
    assert_equal '/content/foo', rs.generate(:controller => "content", :action => "foo")
  end

  def test_route_with_regexp_and_captures_for_controller
    rs.draw do |map|
      map.connect ':controller/:action/:id', :controller => /admin\/(accounts|users)/
    end
    assert_equal({:controller => "admin/accounts", :action => "index"}, rs.recognize_path("/admin/accounts"))
    assert_equal({:controller => "admin/users", :action => "index"}, rs.recognize_path("/admin/users"))
    assert_raise(ActionController::RoutingError) { rs.recognize_path("/admin/products") }
  end

  def test_route_with_regexp_and_dot
    rs.draw do |map|
      map.connect ':controller/:action/:file',
                        :controller => /admin|user/,
                        :action => /upload|download/,
                        :defaults => {:file => nil},
                        :requirements => {:file => %r{[^/]+(\.[^/]+)?}}
    end
    # Without a file extension
    assert_equal '/user/download/file',
      rs.generate(:controller => "user", :action => "download", :file => "file")
    assert_equal(
      {:controller => "user", :action => "download", :file => "file"},
      rs.recognize_path("/user/download/file"))

    # Now, let's try a file with an extension, really a dot (.)
    assert_equal '/user/download/file.jpg',
      rs.generate(
        :controller => "user", :action => "download", :file => "file.jpg")
    assert_equal(
      {:controller => "user", :action => "download", :file => "file.jpg"},
      rs.recognize_path("/user/download/file.jpg"))
  end

  def test_basic_named_route
    rs.draw do |map|
      map.home '', :controller => 'content', :action => 'list'
    end
    x = setup_for_named_route
    assert_equal("http://test.host/",
                 x.send(:home_url))
  end

  def test_named_route_with_option
    rs.draw do |map|
      map.page 'page/:title', :controller => 'content', :action => 'show_page'
    end
    x = setup_for_named_route
    assert_equal("http://test.host/page/new%20stuff",
                 x.send(:page_url, :title => 'new stuff'))
  end

  def test_named_route_with_default
    rs.draw do |map|
      map.page 'page/:title', :controller => 'content', :action => 'show_page', :title => 'AboutPage'
    end
    x = setup_for_named_route
    assert_equal("http://test.host/page/AboutRails",
                 x.send(:page_url, :title => "AboutRails"))

  end

  def test_named_route_with_name_prefix
    rs.draw do |map|
      map.page 'page', :controller => 'content', :action => 'show_page', :name_prefix => 'my_'
    end
    x = setup_for_named_route
    assert_equal("http://test.host/page",
                 x.send(:my_page_url))
  end

  def test_named_route_with_path_prefix
    rs.draw do |map|
      map.page 'page', :controller => 'content', :action => 'show_page', :path_prefix => 'my'
    end
    x = setup_for_named_route
    assert_equal("http://test.host/my/page",
                 x.send(:page_url))
  end

  def test_named_route_with_blank_path_prefix
    rs.draw do |map|
      map.page 'page', :controller => 'content', :action => 'show_page', :path_prefix => ''
    end
    x = setup_for_named_route
    assert_equal("http://test.host/page",
                 x.send(:page_url))
  end

  def test_named_route_with_nested_controller
    rs.draw do |map|
      map.users 'admin/user', :controller => 'admin/user', :action => 'index'
    end
    x = setup_for_named_route
    assert_equal("http://test.host/admin/user",
                 x.send(:users_url))
  end

  def test_optimised_named_route_with_host
    rs.draw do |map|
      map.pages 'pages', :controller => 'content', :action => 'show_page', :host => 'foo.com'
    end
    x = setup_for_named_route
    x.expects(:url_for).with(:host => 'foo.com', :only_path => false, :controller => 'content', :action => 'show_page', :use_route => :pages).once
    x.send(:pages_url)
  end

  def setup_for_named_route
    MockController.build(rs.url_helpers).new
  end

  def test_named_route_without_hash
    rs.draw do |map|
      map.normal ':controller/:action/:id'
    end
  end

  def test_named_route_root
    rs.draw do |map|
      map.root :controller => "hello"
    end
    x = setup_for_named_route
    assert_equal("http://test.host/", x.send(:root_url))
    assert_equal("/", x.send(:root_path))
  end

  def test_named_route_with_regexps
    rs.draw do |map|
      map.article 'page/:year/:month/:day/:title', :controller => 'page', :action => 'show',
        :year => /\d+/, :month => /\d+/, :day => /\d+/
      map.connect ':controller/:action/:id'
    end
    x = setup_for_named_route
    # assert_equal(
    #   {:controller => 'page', :action => 'show', :title => 'hi', :use_route => :article, :only_path => false},
    #   x.send(:article_url, :title => 'hi')
    # )
    assert_equal(
      "http://test.host/page/2005/6/10/hi",
      x.send(:article_url, :title => 'hi', :day => 10, :year => 2005, :month => 6)
    )
  end

  def test_changing_controller
    @rs.draw {|m| m.connect ':controller/:action/:id' }

    assert_equal '/admin/stuff/show/10', rs.generate(
      {:controller => 'stuff', :action => 'show', :id => 10},
      {:controller => 'admin/user', :action => 'index'}
    )
  end

  def test_paths_escaped
    rs.draw do |map|
      map.path 'file/*path', :controller => 'content', :action => 'show_file'
      map.connect ':controller/:action/:id'
    end

    # No + to space in URI escaping, only for query params.
    results = rs.recognize_path "/file/hello+world/how+are+you%3F"
    assert results, "Recognition should have succeeded"
    assert_equal ['hello+world', 'how+are+you?'], results[:path]

    # Use %20 for space instead.
    results = rs.recognize_path "/file/hello%20world/how%20are%20you%3F"
    assert results, "Recognition should have succeeded"
    assert_equal ['hello world', 'how are you?'], results[:path]
  end

  def test_paths_slashes_unescaped_with_ordered_parameters
    rs.draw do |map|
      map.path '/file/*path', :controller => 'content'
    end

    # No / to %2F in URI, only for query params.
    x = setup_for_named_route
    assert_equal("/file/hello/world", x.send(:path_path, ['hello', 'world']))
  end

  def test_non_controllers_cannot_be_matched
    rs.draw do |map|
      map.connect ':controller/:action/:id'
    end
    assert_raise(ActionController::RoutingError) { rs.recognize_path("/not_a/show/10") }
  end

  def test_paths_do_not_accept_defaults
    assert_raise(ActionController::RoutingError) do
      rs.draw do |map|
        map.path 'file/*path', :controller => 'content', :action => 'show_file', :path => %w(fake default)
        map.connect ':controller/:action/:id'
      end
    end

    rs.draw do |map|
      map.path 'file/*path', :controller => 'content', :action => 'show_file', :path => []
      map.connect ':controller/:action/:id'
    end
  end

  def test_should_list_options_diff_when_routing_requirements_dont_match
    rs.draw do |map|
      map.post 'post/:id', :controller=> 'post', :action=> 'show', :requirements => {:id => /\d+/}
    end
    assert_raise(ActionController::RoutingError) { rs.generate(:controller => 'post', :action => 'show', :bad_param => "foo", :use_route => "post") }
  end

  def test_dynamic_path_allowed
    rs.draw do |map|
      map.connect '*path', :controller => 'content', :action => 'show_file'
    end

    assert_equal '/pages/boo', rs.generate(:controller => 'content', :action => 'show_file', :path => %w(pages boo))
  end

  def test_dynamic_recall_paths_allowed
    rs.draw do |map|
      map.connect '*path', :controller => 'content', :action => 'show_file'
    end

    assert_equal '/pages/boo', rs.generate({}, :controller => 'content', :action => 'show_file', :path => %w(pages boo))
  end

  def test_backwards
    rs.draw do |map|
      map.connect 'page/:id/:action', :controller => 'pages', :action => 'show'
      map.connect ':controller/:action/:id'
    end

    assert_equal '/page/20', rs.generate({:id => 20}, {:controller => 'pages', :action => 'show'})
    assert_equal '/page/20', rs.generate(:controller => 'pages', :id => 20, :action => 'show')
    assert_equal '/pages/boo', rs.generate(:controller => 'pages', :action => 'boo')
  end

  def test_route_with_fixnum_default
    rs.draw do |map|
      map.connect 'page/:id', :controller => 'content', :action => 'show_page', :id => 1
      map.connect ':controller/:action/:id'
    end

    assert_equal '/page', rs.generate(:controller => 'content', :action => 'show_page')
    assert_equal '/page', rs.generate(:controller => 'content', :action => 'show_page', :id => 1)
    assert_equal '/page', rs.generate(:controller => 'content', :action => 'show_page', :id => '1')
    assert_equal '/page/10', rs.generate(:controller => 'content', :action => 'show_page', :id => 10)

    assert_equal({:controller => "content", :action => 'show_page', :id => '1'}, rs.recognize_path("/page"))
    assert_equal({:controller => "content", :action => 'show_page', :id => '1'}, rs.recognize_path("/page/1"))
    assert_equal({:controller => "content", :action => 'show_page', :id => '10'}, rs.recognize_path("/page/10"))
  end

  # For newer revision
  def test_route_with_text_default
    rs.draw do |map|
      map.connect 'page/:id', :controller => 'content', :action => 'show_page', :id => 1
      map.connect ':controller/:action/:id'
    end

    assert_equal '/page/foo', rs.generate(:controller => 'content', :action => 'show_page', :id => 'foo')
    assert_equal({:controller => "content", :action => 'show_page', :id => 'foo'}, rs.recognize_path("/page/foo"))

    token = "\321\202\320\265\320\272\321\201\321\202" # 'text' in russian
    token.force_encoding(Encoding::BINARY) if token.respond_to?(:force_encoding)
    escaped_token = CGI::escape(token)

    assert_equal '/page/' + escaped_token, rs.generate(:controller => 'content', :action => 'show_page', :id => token)
    assert_equal({:controller => "content", :action => 'show_page', :id => token}, rs.recognize_path("/page/#{escaped_token}"))
  end

  def test_action_expiry
    @rs.draw {|m| m.connect ':controller/:action/:id' }
    assert_equal '/content', rs.generate({:controller => 'content'}, {:controller => 'content', :action => 'show'})
  end

  def test_requirement_should_prevent_optional_id
    rs.draw do |map|
      map.post 'post/:id', :controller=> 'post', :action=> 'show', :requirements => {:id => /\d+/}
    end

    assert_equal '/post/10', rs.generate(:controller => 'post', :action => 'show', :id => 10)

    assert_raise ActionController::RoutingError do
      rs.generate(:controller => 'post', :action => 'show')
    end
  end

  def test_both_requirement_and_optional
    rs.draw do |map|
      map.blog('test/:year', :controller => 'post', :action => 'show',
        :defaults => { :year => nil },
        :requirements => { :year => /\d{4}/ }
      )
      map.connect ':controller/:action/:id'
    end

    assert_equal '/test', rs.generate(:controller => 'post', :action => 'show')
    assert_equal '/test', rs.generate(:controller => 'post', :action => 'show', :year => nil)

    x = setup_for_named_route
    assert_equal("http://test.host/test",
                 x.send(:blog_url))
  end

  def test_set_to_nil_forgets
    rs.draw do |map|
      map.connect 'pages/:year/:month/:day', :controller => 'content', :action => 'list_pages', :month => nil, :day => nil
      map.connect ':controller/:action/:id'
    end

    assert_equal '/pages/2005',
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005)
    assert_equal '/pages/2005/6',
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005, :month => 6)
    assert_equal '/pages/2005/6/12',
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005, :month => 6, :day => 12)

    assert_equal '/pages/2005/6/4',
      rs.generate({:day => 4}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})

    assert_equal '/pages/2005/6',
      rs.generate({:day => nil}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})

    assert_equal '/pages/2005',
      rs.generate({:day => nil, :month => nil}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})
  end

  def test_url_with_no_action_specified
    rs.draw do |map|
      map.connect '', :controller => 'content'
      map.connect ':controller/:action/:id'
    end

    assert_equal '/', rs.generate(:controller => 'content', :action => 'index')
    assert_equal '/', rs.generate(:controller => 'content')
  end

  def test_named_url_with_no_action_specified
    rs.draw do |map|
      map.home '', :controller => 'content'
      map.connect ':controller/:action/:id'
    end

    assert_equal '/', rs.generate(:controller => 'content', :action => 'index')
    assert_equal '/', rs.generate(:controller => 'content')

    x = setup_for_named_route
    assert_equal("http://test.host/",
                 x.send(:home_url))
  end

  def test_url_generated_when_forgetting_action
    [{:controller => 'content', :action => 'index'}, {:controller => 'content'}].each do |hash|
      rs.draw do |map|
        map.home '', hash
        map.connect ':controller/:action/:id'
      end
      assert_equal '/', rs.generate({:action => nil}, {:controller => 'content', :action => 'hello'})
      assert_equal '/', rs.generate({:controller => 'content'})
      assert_equal '/content/hi', rs.generate({:controller => 'content', :action => 'hi'})
    end
  end

  def test_named_route_method
    rs.draw do |map|
      map.categories 'categories', :controller => 'content', :action => 'categories'
      map.connect ':controller/:action/:id'
    end

    assert_equal '/categories', rs.generate(:controller => 'content', :action => 'categories')
    assert_equal '/content/hi', rs.generate({:controller => 'content', :action => 'hi'})
  end

  def test_named_routes_array
    test_named_route_method
    assert_equal [:categories], rs.named_routes.names
  end

  def test_nil_defaults
    rs.draw do |map|
      map.connect 'journal',
        :controller => 'content',
        :action => 'list_journal',
        :date => nil, :user_id => nil
      map.connect ':controller/:action/:id'
    end

    assert_equal '/journal', rs.generate(:controller => 'content', :action => 'list_journal', :date => nil, :user_id => nil)
  end

  def setup_request_method_routes_for(method)
    rs.draw do |r|
      r.connect '/match', :controller => 'books', :action => 'get', :conditions => { :method => :get }
      r.connect '/match', :controller => 'books', :action => 'post', :conditions => { :method => :post }
      r.connect '/match', :controller => 'books', :action => 'put', :conditions => { :method => :put }
      r.connect '/match', :controller => 'books', :action => 'delete', :conditions => { :method => :delete }
    end
  end

  %w(GET POST PUT DELETE).each do |request_method|
    define_method("test_request_method_recognized_with_#{request_method}") do
      setup_request_method_routes_for(request_method)
      params = rs.recognize_path("/match", :method => request_method)
      assert_equal request_method.downcase, params[:action]
    end
  end

  def test_recognize_array_of_methods
    rs.draw do |r|
      r.connect '/match', :controller => 'books', :action => 'get_or_post', :conditions => { :method => [:get, :post] }
      r.connect '/match', :controller => 'books', :action => 'not_get_or_post'
    end

    params = rs.recognize_path("/match", :method => :post)
    assert_equal 'get_or_post', params[:action]

    params = rs.recognize_path("/match", :method => :put)
    assert_equal 'not_get_or_post', params[:action]
  end

  def test_subpath_recognized
    rs.draw do |r|
      r.connect '/books/:id/edit', :controller => 'subpath_books', :action => 'edit'
      r.connect '/items/:id/:action', :controller => 'subpath_books'
      r.connect '/posts/new/:action', :controller => 'subpath_books'
      r.connect '/posts/:id', :controller => 'subpath_books', :action => "show"
    end

    hash = rs.recognize_path "/books/17/edit"
    assert_not_nil hash
    assert_equal %w(subpath_books 17 edit), [hash[:controller], hash[:id], hash[:action]]

    hash = rs.recognize_path "/items/3/complete"
    assert_not_nil hash
    assert_equal %w(subpath_books 3 complete), [hash[:controller], hash[:id], hash[:action]]

    hash = rs.recognize_path "/posts/new/preview"
    assert_not_nil hash
    assert_equal %w(subpath_books preview), [hash[:controller], hash[:action]]

    hash = rs.recognize_path "/posts/7"
    assert_not_nil hash
    assert_equal %w(subpath_books show 7), [hash[:controller], hash[:action], hash[:id]]
  end

  def test_subpath_generated
    rs.draw do |r|
      r.connect '/books/:id/edit', :controller => 'subpath_books', :action => 'edit'
      r.connect '/items/:id/:action', :controller => 'subpath_books'
      r.connect '/posts/new/:action', :controller => 'subpath_books'
    end

    assert_equal "/books/7/edit", rs.generate(:controller => "subpath_books", :id => 7, :action => "edit")
    assert_equal "/items/15/complete", rs.generate(:controller => "subpath_books", :id => 15, :action => "complete")
    assert_equal "/posts/new/preview", rs.generate(:controller => "subpath_books", :action => "preview")
  end

  def test_failed_requirements_raises_exception_with_violated_requirements
    rs.draw do |r|
      r.foo_with_requirement 'foos/:id', :controller=>'foos', :requirements=>{:id=>/\d+/}
    end

    x = setup_for_named_route
    assert_raise(ActionController::RoutingError) do
      x.send(:foo_with_requirement_url, "I am Against the requirements")
    end
  end

  def test_routes_changed_correctly_after_clear
    rs = ::ActionController::Routing::RouteSet.new
    rs.draw do |r|
      r.connect 'ca', :controller => 'ca', :action => "aa"
      r.connect 'cb', :controller => 'cb', :action => "ab"
      r.connect 'cc', :controller => 'cc', :action => "ac"
      r.connect ':controller/:action/:id'
      r.connect ':controller/:action/:id.:format'
    end

    hash = rs.recognize_path "/cc"

    assert_not_nil hash
    assert_equal %w(cc ac), [hash[:controller], hash[:action]]

    rs.draw do |r|
      r.connect 'cb', :controller => 'cb', :action => "ab"
      r.connect 'cc', :controller => 'cc', :action => "ac"
      r.connect ':controller/:action/:id'
      r.connect ':controller/:action/:id.:format'
    end

    hash = rs.recognize_path "/cc"

    assert_not_nil hash
    assert_equal %w(cc ac), [hash[:controller], hash[:action]]

  end
end

class RouteSetTest < ActiveSupport::TestCase
  def set
    @set ||= ROUTING::RouteSet.new
  end

  def request
    @request ||= ActionController::TestRequest.new
  end

  def default_route_set
    @default_route_set ||= begin
      set = ROUTING::RouteSet.new
      set.draw do |map|
        map.connect '/:controller/:action/:id/'
      end
      set
    end
  end

  def test_generate_extras
    set.draw { |m| m.connect ':controller/:action/:id' }
    path, extras = set.generate_extras(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal "/foo/bar/15", path
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_extra_keys
    set.draw { |m| m.connect ':controller/:action/:id' }
    extras = set.extra_keys(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_generate_extras_not_first
    set.draw do |map|
      map.connect ':controller/:action/:id.:format'
      map.connect ':controller/:action/:id'
    end
    path, extras = set.generate_extras(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal "/foo/bar/15", path
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_generate_not_first
    set.draw do |map|
      map.connect ':controller/:action/:id.:format'
      map.connect ':controller/:action/:id'
    end
    assert_equal "/foo/bar/15?this=hello", set.generate(:controller => "foo", :action => "bar", :id => 15, :this => "hello")
  end

  def test_extra_keys_not_first
    set.draw do |map|
      map.connect ':controller/:action/:id.:format'
      map.connect ':controller/:action/:id'
    end
    extras = set.extra_keys(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_draw
    assert_equal 0, set.routes.size
    set.draw do |map|
      map.connect '/hello/world', :controller => 'a', :action => 'b'
    end
    assert_equal 1, set.routes.size
  end

  def test_draw_symbol_controller_name
    assert_equal 0, set.routes.size
    set.draw do |map|
      map.connect '/users/index', :controller => :users, :action => :index
    end
    params = set.recognize_path('/users/index', :method => :get)
    assert_equal 1, set.routes.size
  end

  def test_named_draw
    assert_equal 0, set.routes.size
    set.draw do |map|
      map.hello '/hello/world', :controller => 'a', :action => 'b'
    end
    assert_equal 1, set.routes.size
    assert_equal set.routes.first, set.named_routes[:hello]
  end

  def test_later_named_routes_take_precedence
    set.draw do |map|
      map.hello '/hello/world', :controller => 'a', :action => 'b'
      map.hello '/hello', :controller => 'a', :action => 'b'
    end
    assert_equal set.routes.last, set.named_routes[:hello]
  end

  def setup_named_route_test
    set.draw do |map|
      map.show '/people/:id', :controller => 'people', :action => 'show'
      map.index '/people', :controller => 'people', :action => 'index'
      map.multi '/people/go/:foo/:bar/joe/:id', :controller => 'people', :action => 'multi'
      map.users '/admin/users', :controller => 'admin/users', :action => 'index'
    end

    MockController.build(set.url_helpers).new
  end

  def test_named_route_hash_access_method
    controller = setup_named_route_test

    assert_equal(
      { :controller => 'people', :action => 'show', :id => 5, :use_route => :show, :only_path => false },
      controller.send(:hash_for_show_url, :id => 5))

    assert_equal(
      { :controller => 'people', :action => 'index', :use_route => :index, :only_path => false },
      controller.send(:hash_for_index_url))

    assert_equal(
      { :controller => 'people', :action => 'show', :id => 5, :use_route => :show, :only_path => true },
      controller.send(:hash_for_show_path, :id => 5)
    )
  end

  def test_named_route_url_method
    controller = setup_named_route_test

    assert_equal "http://test.host/people/5", controller.send(:show_url, :id => 5)
    assert_equal "/people/5", controller.send(:show_path, :id => 5)

    assert_equal "http://test.host/people", controller.send(:index_url)
    assert_equal "/people", controller.send(:index_path)

    assert_equal "http://test.host/admin/users", controller.send(:users_url)
    assert_equal '/admin/users', controller.send(:users_path)
    assert_equal '/admin/users', set.generate(controller.send(:hash_for_users_url), {:controller => 'users', :action => 'index'})
  end

  def test_named_route_url_method_with_anchor
    controller = setup_named_route_test

    assert_equal "http://test.host/people/5#location", controller.send(:show_url, :id => 5, :anchor => 'location')
    assert_equal "/people/5#location", controller.send(:show_path, :id => 5, :anchor => 'location')

    assert_equal "http://test.host/people#location", controller.send(:index_url, :anchor => 'location')
    assert_equal "/people#location", controller.send(:index_path, :anchor => 'location')

    assert_equal "http://test.host/admin/users#location", controller.send(:users_url, :anchor => 'location')
    assert_equal '/admin/users#location', controller.send(:users_path, :anchor => 'location')

    assert_equal "http://test.host/people/go/7/hello/joe/5#location",
      controller.send(:multi_url, 7, "hello", 5, :anchor => 'location')

    assert_equal "http://test.host/people/go/7/hello/joe/5?baz=bar#location",
      controller.send(:multi_url, 7, "hello", 5, :baz => "bar", :anchor => 'location')

    assert_equal "http://test.host/people?baz=bar#location",
      controller.send(:index_url, :baz => "bar", :anchor => 'location')
  end

  def test_named_route_url_method_with_port
    controller = setup_named_route_test
    assert_equal "http://test.host:8080/people/5", controller.send(:show_url, 5, :port=>8080)
  end

  def test_named_route_url_method_with_host
    controller = setup_named_route_test
    assert_equal "http://some.example.com/people/5", controller.send(:show_url, 5, :host=>"some.example.com")
  end

  def test_named_route_url_method_with_protocol
    controller = setup_named_route_test
    assert_equal "https://test.host/people/5", controller.send(:show_url, 5, :protocol => "https")
  end

  def test_named_route_url_method_with_ordered_parameters
    controller = setup_named_route_test
    assert_equal "http://test.host/people/go/7/hello/joe/5",
      controller.send(:multi_url, 7, "hello", 5)
  end

  def test_named_route_url_method_with_ordered_parameters_and_hash
    controller = setup_named_route_test
    assert_equal "http://test.host/people/go/7/hello/joe/5?baz=bar",
      controller.send(:multi_url, 7, "hello", 5, :baz => "bar")
  end

  def test_named_route_url_method_with_ordered_parameters_and_empty_hash
    controller = setup_named_route_test
    assert_equal "http://test.host/people/go/7/hello/joe/5",
      controller.send(:multi_url, 7, "hello", 5, {})
  end

  def test_named_route_url_method_with_no_positional_arguments
    controller = setup_named_route_test
    assert_equal "http://test.host/people?baz=bar",
      controller.send(:index_url, :baz => "bar")
  end

  def test_draw_default_route
    set.draw do |map|
      map.connect '/:controller/:action/:id'
    end

    assert_equal 1, set.routes.size

    assert_equal '/users/show/10', set.generate(:controller => 'users', :action => 'show', :id => 10)
    assert_equal '/users/index/10', set.generate(:controller => 'users', :id => 10)

    assert_equal({:controller => 'users', :action => 'index', :id => '10'}, set.recognize_path('/users/index/10'))
    assert_equal({:controller => 'users', :action => 'index', :id => '10'}, set.recognize_path('/users/index/10/'))
  end

  def test_draw_default_route_with_default_controller
    set.draw do |map|
      map.connect '/:controller/:action/:id', :controller => 'users'
    end
    assert_equal({:controller => 'users', :action => 'index'}, set.recognize_path('/'))
  end

  def test_route_with_parameter_shell
    set.draw do |map|
      map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+/
      map.connect '/:controller/:action/:id'
    end

    assert_equal({:controller => 'pages', :action => 'index'}, set.recognize_path('/pages'))
    assert_equal({:controller => 'pages', :action => 'index'}, set.recognize_path('/pages/index'))
    assert_equal({:controller => 'pages', :action => 'list'}, set.recognize_path('/pages/list'))

    assert_equal({:controller => 'pages', :action => 'show', :id => '10'}, set.recognize_path('/pages/show/10'))
    assert_equal({:controller => 'pages', :action => 'show', :id => '10'}, set.recognize_path('/page/10'))
  end

  def test_route_constraints_on_request_object_with_anchors_are_valid
    assert_nothing_raised do
      set.draw do
        match 'page/:id' => 'pages#show', :constraints => { :host => /^foo$/ }
      end
    end
  end

  def test_route_constraints_with_anchor_chars_are_invalid
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /^\d+/
      end
    end
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\A\d+/
      end
    end
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+$/
      end
    end
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+\Z/
      end
    end
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /\d+\z/
      end
    end
  end

  def test_route_requirements_with_invalid_http_method_is_invalid
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'valid/route', :controller => 'pages', :action => 'show', :conditions => {:method => :invalid}
      end
    end
  end

  def test_route_requirements_with_options_method_condition_is_valid
    assert_nothing_raised do
      set.draw do |map|
        map.connect 'valid/route', :controller => 'pages', :action => 'show', :conditions => {:method => :options}
      end
    end
  end

  def test_route_requirements_with_head_method_condition_is_invalid
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'valid/route', :controller => 'pages', :action => 'show', :conditions => {:method => :head}
      end
    end
  end

  def test_recognize_with_encoded_id_and_regex
    set.draw do |map|
      map.connect 'page/:id', :controller => 'pages', :action => 'show', :id => /[a-zA-Z0-9\+]+/
    end

    assert_equal({:controller => 'pages', :action => 'show', :id => '10'}, set.recognize_path('/page/10'))
    assert_equal({:controller => 'pages', :action => 'show', :id => 'hello+world'}, set.recognize_path('/page/hello+world'))
  end

  def test_recognize_with_conditions
    set.draw do |map|
      map.with_options(:controller => "people") do |people|
        people.people  "/people",     :action => "index",   :conditions => { :method => :get }
        people.connect "/people",     :action => "create",  :conditions => { :method => :post }
        people.person  "/people/:id", :action => "show",    :conditions => { :method => :get }
        people.connect "/people/:id", :action => "update",  :conditions => { :method => :put }
        people.connect "/people/:id", :action => "destroy", :conditions => { :method => :delete }
      end
    end

    params = set.recognize_path("/people", :method => :get)
    assert_equal("index", params[:action])

    params = set.recognize_path("/people", :method => :post)
    assert_equal("create", params[:action])

    params = set.recognize_path("/people", :method => :put)
    assert_equal("update", params[:action])

    assert_raise(ActionController::UnknownHttpMethod) {
      set.recognize_path("/people", :method => :bacon)
    }

    params = set.recognize_path("/people/5", :method => :get)
    assert_equal("show", params[:action])
    assert_equal("5", params[:id])

    params = set.recognize_path("/people/5", :method => :put)
    assert_equal("update", params[:action])
    assert_equal("5", params[:id])

    params = set.recognize_path("/people/5", :method => :delete)
    assert_equal("destroy", params[:action])
    assert_equal("5", params[:id])

    assert_raise(ActionController::RoutingError) {
      set.recognize_path("/people/5", :method => :post)
    }
  end

  def test_recognize_with_alias_in_conditions
    set.draw do |map|
      map.people "/people", :controller => 'people', :action => "index",
        :conditions => { :method => :get }
      map.root   :people
    end

    params = set.recognize_path("/people", :method => :get)
    assert_equal("people", params[:controller])
    assert_equal("index", params[:action])

    params = set.recognize_path("/", :method => :get)
    assert_equal("people", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_typo_recognition
    set.draw do |map|
      map.connect 'articles/:year/:month/:day/:title',
             :controller => 'articles', :action => 'permalink',
             :year => /\d{4}/, :day => /\d{1,2}/, :month => /\d{1,2}/
    end

    params = set.recognize_path("/articles/2005/11/05/a-very-interesting-article", :method => :get)
    assert_equal("permalink", params[:action])
    assert_equal("2005", params[:year])
    assert_equal("11", params[:month])
    assert_equal("05", params[:day])
    assert_equal("a-very-interesting-article", params[:title])
  end

  def test_routing_traversal_does_not_load_extra_classes
    assert !Object.const_defined?("Profiler__"), "Profiler should not be loaded"
    set.draw do |map|
      map.connect '/profile', :controller => 'profile'
    end

    params = set.recognize_path("/profile") rescue nil

    assert !Object.const_defined?("Profiler__"), "Profiler should not be loaded"
  end

  def test_recognize_with_conditions_and_format
    set.draw do |map|
      map.with_options(:controller => "people") do |people|
        people.person  "/people/:id", :action => "show",    :conditions => { :method => :get }
        people.connect "/people/:id", :action => "update",  :conditions => { :method => :put }
        people.connect "/people/:id.:_format", :action => "show", :conditions => { :method => :get }
      end
    end

    params = set.recognize_path("/people/5", :method => :get)
    assert_equal("show", params[:action])
    assert_equal("5", params[:id])

    params = set.recognize_path("/people/5", :method => :put)
    assert_equal("update", params[:action])

    params = set.recognize_path("/people/5.png", :method => :get)
    assert_equal("show", params[:action])
    assert_equal("5", params[:id])
    assert_equal("png", params[:_format])
  end

  def test_generate_with_default_action
    set.draw do |map|
      map.connect "/people", :controller => "people"
      map.connect "/people/list", :controller => "people", :action => "list"
    end

    url = set.generate(:controller => "people", :action => "list")
    assert_equal "/people/list", url
  end

  def test_root_map
    set.draw { |map| map.root :controller => "people" }

    params = set.recognize_path("", :method => :get)
    assert_equal("people", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_namespace
    set.draw do |map|

      map.namespace 'api' do |api|
        api.route 'inventory', :controller => "products", :action => 'inventory'
      end

    end

    params = set.recognize_path("/api/inventory", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("inventory", params[:action])
  end

  def test_namespaced_root_map
    set.draw do |map|

      map.namespace 'api' do |api|
        api.root :controller => "products"
      end

    end

    params = set.recognize_path("/api", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_namespace_with_path_prefix
    set.draw do |map|
      map.namespace 'api', :path_prefix => 'prefix' do |api|
        api.route 'inventory', :controller => "products", :action => 'inventory'
      end
    end

    params = set.recognize_path("/prefix/inventory", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("inventory", params[:action])
  end

  def test_namespace_with_blank_path_prefix
    set.draw do |map|
      map.namespace 'api', :path_prefix => '' do |api|
        api.route 'inventory', :controller => "products", :action => 'inventory'
      end
    end

    params = set.recognize_path("/inventory", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("inventory", params[:action])
  end

  def test_generate_changes_controller_module
    set.draw { |map| map.connect ':controller/:action/:id' }
    current = { :controller => "bling/bloop", :action => "bap", :id => 9 }
    url = set.generate({:controller => "foo/bar", :action => "baz", :id => 7}, current)
    assert_equal "/foo/bar/baz/7", url
  end

  # def test_id_is_not_impossibly_sticky
  #   set.draw do |map|
  #     map.connect 'foo/:number', :controller => "people", :action => "index"
  #     map.connect ':controller/:action/:id'
  #   end
  #
  #   url = set.generate({:controller => "people", :action => "index", :number => 3},
  #     {:controller => "people", :action => "index", :id => "21"})
  #   assert_equal "/foo/3", url
  # end

  def test_id_is_sticky_when_it_ought_to_be
    set.draw do |map|
      map.connect ':controller/:id/:action'
    end

    url = set.generate({:action => "destroy"}, {:controller => "people", :action => "show", :id => "7"})
    assert_equal "/people/7/destroy", url
  end

  def test_use_static_path_when_possible
    set.draw do |map|
      map.connect 'about', :controller => "welcome", :action => "about"
      map.connect ':controller/:action/:id'
    end

    url = set.generate({:controller => "welcome", :action => "about"},
      {:controller => "welcome", :action => "get", :id => "7"})
    assert_equal "/about", url
  end

  def test_generate
    set.draw { |map| map.connect ':controller/:action/:id' }

    args = { :controller => "foo", :action => "bar", :id => "7", :x => "y" }
    assert_equal "/foo/bar/7?x=y", set.generate(args)
    assert_equal ["/foo/bar/7", [:x]], set.generate_extras(args)
    assert_equal [:x], set.extra_keys(args)
  end

  def test_generate_with_path_prefix
    set.draw { |map| map.connect ':controller/:action/:id', :path_prefix => 'my' }

    args = { :controller => "foo", :action => "bar", :id => "7", :x => "y" }
    assert_equal "/my/foo/bar/7?x=y", set.generate(args)
  end

  def test_generate_with_blank_path_prefix
    set.draw { |map| map.connect ':controller/:action/:id', :path_prefix => '' }

    args = { :controller => "foo", :action => "bar", :id => "7", :x => "y" }
    assert_equal "/foo/bar/7?x=y", set.generate(args)
  end

  def test_named_routes_are_never_relative_to_modules
    set.draw do |map|
      map.connect "/connection/manage/:action", :controller => 'connection/manage'
      map.connect "/connection/connection", :controller => "connection/connection"
      map.family_connection "/connection", :controller => "connection"
    end

    url = set.generate({:controller => "connection"}, {:controller => 'connection/manage'})
    assert_equal "/connection/connection", url

    url = set.generate({:use_route => :family_connection, :controller => "connection"}, {:controller => 'connection/manage'})
    assert_equal "/connection", url
  end

  def test_action_left_off_when_id_is_recalled
    set.draw do |map|
      map.connect ':controller/:action/:id'
    end
    assert_equal '/books', set.generate(
      {:controller => 'books', :action => 'index'},
      {:controller => 'books', :action => 'show', :id => '10'}
    )
  end

  def test_query_params_will_be_shown_when_recalled
    set.draw do |map|
      map.connect 'show_weblog/:parameter', :controller => 'weblog', :action => 'show'
      map.connect ':controller/:action/:id'
    end
    assert_equal '/weblog/edit?parameter=1', set.generate(
      {:action => 'edit', :parameter => 1},
      {:controller => 'weblog', :action => 'show', :parameter => 1}
    )
  end

  def test_format_is_not_inherit
    set.draw do |map|
      map.connect '/posts.:format', :controller => 'posts'
    end

    assert_equal '/posts', set.generate(
      {:controller => 'posts'},
      {:controller => 'posts', :action => 'index', :format => 'xml'}
    )

    assert_equal '/posts.xml', set.generate(
      {:controller => 'posts', :format => 'xml'},
      {:controller => 'posts', :action => 'index', :format => 'xml'}
    )
  end

  def test_expiry_determination_should_consider_values_with_to_param
    set.draw { |map| map.connect 'projects/:project_id/:controller/:action' }
    assert_equal '/projects/1/weblog/show', set.generate(
      {:action => 'show', :project_id => 1},
      {:controller => 'weblog', :action => 'show', :project_id => '1'})
  end

  def test_named_route_in_nested_resource
    set.draw do |map|
      map.resources :projects do |project|
        project.milestones 'milestones', :controller => 'milestones', :action => 'index'
      end
    end

    params = set.recognize_path("/projects/1/milestones", :method => :get)
    assert_equal("milestones", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_setting_root_in_namespace_using_symbol
    assert_nothing_raised do
      set.draw do |map|
        map.namespace :admin do |admin|
          admin.root :controller => 'home'
        end
      end
    end
  end

  def test_setting_root_in_namespace_using_string
    assert_nothing_raised do
      set.draw do |map|
        map.namespace 'admin' do |admin|
          admin.root :controller => 'home'
        end
      end
    end
  end

  def test_route_requirements_with_unsupported_regexp_options_must_error
    assert_raise ArgumentError do
      set.draw do |map|
        map.connect 'page/:name', :controller => 'pages',
          :action => 'show',
          :requirements => {:name => /(david|jamis)/m}
      end
    end
  end

  def test_route_requirements_with_supported_options_must_not_error
    assert_nothing_raised do
      set.draw do |map|
        map.connect 'page/:name', :controller => 'pages',
          :action => 'show',
          :requirements => {:name => /(david|jamis)/i}
      end
    end
    assert_nothing_raised do
      set.draw do |map|
        map.connect 'page/:name', :controller => 'pages',
          :action => 'show',
          :requirements => {:name => / # Desperately overcommented regexp
                                      ( #Either
                                       david #The Creator
                                      | #Or
                                        jamis #The Deployer
                                      )/x}
      end
    end
  end

  def test_route_requirement_recognize_with_ignore_case
    set.draw do |map|
      map.connect 'page/:name', :controller => 'pages',
        :action => 'show',
        :requirements => {:name => /(david|jamis)/i}
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => 'jamis'}, set.recognize_path('/page/jamis'))
    assert_raise ActionController::RoutingError do
      set.recognize_path('/page/davidjamis')
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => 'DAVID'}, set.recognize_path('/page/DAVID'))
  end

  def test_route_requirement_generate_with_ignore_case
    set.draw do |map|
      map.connect 'page/:name', :controller => 'pages',
        :action => 'show',
        :requirements => {:name => /(david|jamis)/i}
    end

    url = set.generate({:controller => 'pages', :action => 'show', :name => 'david'})
    assert_equal "/page/david", url
    assert_raise ActionController::RoutingError do
      url = set.generate({:controller => 'pages', :action => 'show', :name => 'davidjamis'})
    end
    url = set.generate({:controller => 'pages', :action => 'show', :name => 'JAMIS'})
    assert_equal "/page/JAMIS", url
  end

  def test_route_requirement_recognize_with_extended_syntax
    set.draw do |map|
      map.connect 'page/:name', :controller => 'pages',
        :action => 'show',
        :requirements => {:name => / # Desperately overcommented regexp
                                    ( #Either
                                     david #The Creator
                                    | #Or
                                      jamis #The Deployer
                                    )/x}
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => 'jamis'}, set.recognize_path('/page/jamis'))
    assert_equal({:controller => 'pages', :action => 'show', :name => 'david'}, set.recognize_path('/page/david'))
    assert_raise ActionController::RoutingError do
      set.recognize_path('/page/david #The Creator')
    end
    assert_raise ActionController::RoutingError do
      set.recognize_path('/page/David')
    end
  end

  def test_route_requirement_generate_with_extended_syntax
    set.draw do |map|
      map.connect 'page/:name', :controller => 'pages',
        :action => 'show',
        :requirements => {:name => / # Desperately overcommented regexp
                                    ( #Either
                                     david #The Creator
                                    | #Or
                                      jamis #The Deployer
                                    )/x}
    end

    url = set.generate({:controller => 'pages', :action => 'show', :name => 'david'})
    assert_equal "/page/david", url
    assert_raise ActionController::RoutingError do
      url = set.generate({:controller => 'pages', :action => 'show', :name => 'davidjamis'})
    end
    assert_raise ActionController::RoutingError do
      url = set.generate({:controller => 'pages', :action => 'show', :name => 'JAMIS'})
    end
  end

  def test_route_requirement_generate_with_xi_modifiers
    set.draw do |map|
      map.connect 'page/:name', :controller => 'pages',
        :action => 'show',
        :requirements => {:name => / # Desperately overcommented regexp
                                    ( #Either
                                     david #The Creator
                                    | #Or
                                      jamis #The Deployer
                                    )/xi}
    end

    url = set.generate({:controller => 'pages', :action => 'show', :name => 'JAMIS'})
    assert_equal "/page/JAMIS", url
  end

  def test_route_requirement_recognize_with_xi_modifiers
    set.draw do |map|
      map.connect 'page/:name', :controller => 'pages',
        :action => 'show',
        :requirements => {:name => / # Desperately overcommented regexp
                                    ( #Either
                                     david #The Creator
                                    | #Or
                                      jamis #The Deployer
                                    )/xi}
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => 'JAMIS'}, set.recognize_path('/page/JAMIS'))
  end

  def test_routes_with_symbols
    set.draw do |map|
      map.connect 'unnamed', :controller => :pages, :action => :show, :name => :as_symbol
      map.named   'named',   :controller => :pages, :action => :show, :name => :as_symbol
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => :as_symbol}, set.recognize_path('/unnamed'))
    assert_equal({:controller => 'pages', :action => 'show', :name => :as_symbol}, set.recognize_path('/named'))
  end

  def test_regexp_chunk_should_add_question_mark_for_optionals
    set.draw do |map|
      map.connect '/', :controller => 'foo'
      map.connect '/hello', :controller => 'bar'
    end

    assert_equal '/', set.generate(:controller => 'foo')
    assert_equal '/hello', set.generate(:controller => 'bar')

    assert_equal({:controller => "foo", :action => "index"}, set.recognize_path('/'))
    assert_equal({:controller => "bar", :action => "index"}, set.recognize_path('/hello'))
  end

  def test_assign_route_options_with_anchor_chars
    set.draw do |map|
      map.connect '/cars/:action/:person/:car/', :controller => 'cars'
    end

    assert_equal '/cars/buy/1/2', set.generate(:controller => 'cars', :action => 'buy', :person => '1', :car => '2')

    assert_equal({:controller => "cars", :action => "buy", :person => "1", :car => "2"}, set.recognize_path('/cars/buy/1/2'))
  end

  def test_segmentation_of_dot_path
    set.draw do |map|
      map.connect '/books/:action.rss', :controller => 'books'
    end

    assert_equal '/books/list.rss', set.generate(:controller => 'books', :action => 'list')

    assert_equal({:controller => "books", :action => "list"}, set.recognize_path('/books/list.rss'))
  end

  def test_segmentation_of_dynamic_dot_path
    set.draw do |map|
      map.connect '/books/:action.:format', :controller => 'books'
    end

    assert_equal '/books/list.rss', set.generate(:controller => 'books', :action => 'list', :format => 'rss')
    assert_equal '/books/list.xml', set.generate(:controller => 'books', :action => 'list', :format => 'xml')
    assert_equal '/books/list', set.generate(:controller => 'books', :action => 'list')
    assert_equal '/books', set.generate(:controller => 'books', :action => 'index')

    assert_equal({:controller => "books", :action => "list", :format => "rss"}, set.recognize_path('/books/list.rss'))
    assert_equal({:controller => "books", :action => "list", :format => "xml"}, set.recognize_path('/books/list.xml'))
    assert_equal({:controller => "books", :action => "list"}, set.recognize_path('/books/list'))
    assert_equal({:controller => "books", :action => "index"}, set.recognize_path('/books'))
  end

  def test_slashes_are_implied
    ['/:controller/:action/:id/', '/:controller/:action/:id',
      ':controller/:action/:id', '/:controller/:action/:id/'
    ].each do |path|
      @set = nil
      set.draw { |map| map.connect(path) }

      assert_equal '/content', set.generate(:controller => 'content', :action => 'index')
      assert_equal '/content/list', set.generate(:controller => 'content', :action => 'list')
      assert_equal '/content/show/1', set.generate(:controller => 'content', :action => 'show', :id => '1')

      assert_equal({:controller => "content", :action => "index"}, set.recognize_path('/content'))
      assert_equal({:controller => "content", :action => "index"}, set.recognize_path('/content/index'))
      assert_equal({:controller => "content", :action => "list"}, set.recognize_path('/content/list'))
      assert_equal({:controller => "content", :action => "show", :id => "1"}, set.recognize_path('/content/show/1'))
    end
  end

  def test_default_route_recognition
    expected = {:controller => 'pages', :action => 'show', :id => '10'}
    assert_equal expected, default_route_set.recognize_path('/pages/show/10')
    assert_equal expected, default_route_set.recognize_path('/pages/show/10/')

    expected[:id] = 'jamis'
    assert_equal expected, default_route_set.recognize_path('/pages/show/jamis/')

    expected.delete :id
    assert_equal expected, default_route_set.recognize_path('/pages/show')
    assert_equal expected, default_route_set.recognize_path('/pages/show/')

    expected[:action] = 'index'
    assert_equal expected, default_route_set.recognize_path('/pages/')
    assert_equal expected, default_route_set.recognize_path('/pages')

    assert_raise(ActionController::RoutingError) { default_route_set.recognize_path('/') }
    assert_raise(ActionController::RoutingError) { default_route_set.recognize_path('/pages/how/goood/it/is/to/be/free') }
  end

  def test_default_route_should_omit_default_action
    assert_equal '/accounts', default_route_set.generate({:controller => 'accounts', :action => 'index'})
  end

  def test_default_route_should_include_default_action_when_id_present
    assert_equal '/accounts/index/20', default_route_set.generate({:controller => 'accounts', :action => 'index', :id => '20'})
  end

  def test_default_route_should_work_with_action_but_no_id
    assert_equal '/accounts/list_all', default_route_set.generate({:controller => 'accounts', :action => 'list_all'})
  end

  def test_default_route_should_uri_escape_pluses
    expected = { :controller => 'pages', :action => 'show', :id => 'hello world' }
    assert_equal expected, default_route_set.recognize_path('/pages/show/hello%20world')
    assert_equal '/pages/show/hello%20world', default_route_set.generate(expected, expected)

    expected[:id] = 'hello+world'
    assert_equal expected, default_route_set.recognize_path('/pages/show/hello+world')
    assert_equal expected, default_route_set.recognize_path('/pages/show/hello%2Bworld')
    assert_equal '/pages/show/hello+world', default_route_set.generate(expected, expected)
  end

  def test_build_empty_query_string
    assert_uri_equal '/foo', default_route_set.generate({:controller => 'foo'})
  end

  def test_build_query_string_with_nil_value
    assert_uri_equal '/foo', default_route_set.generate({:controller => 'foo', :x => nil})
  end

  def test_simple_build_query_string
    assert_uri_equal '/foo?x=1&y=2', default_route_set.generate({:controller => 'foo', :x => '1', :y => '2'})
  end

  def test_convert_ints_build_query_string
    assert_uri_equal '/foo?x=1&y=2', default_route_set.generate({:controller => 'foo', :x => 1, :y => 2})
  end

  def test_escape_spaces_build_query_string
    assert_uri_equal '/foo?x=hello+world&y=goodbye+world', default_route_set.generate({:controller => 'foo', :x => 'hello world', :y => 'goodbye world'})
  end

  def test_expand_array_build_query_string
    assert_uri_equal '/foo?x[]=1&x[]=2', default_route_set.generate({:controller => 'foo', :x => [1, 2]})
  end

  def test_escape_spaces_build_query_string_selected_keys
    assert_uri_equal '/foo?x=hello+world', default_route_set.generate({:controller => 'foo', :x => 'hello world'})
  end

  def test_generate_with_default_params
    set.draw do |map|
      map.connect 'dummy/page/:page', :controller => 'dummy'
      map.connect 'dummy/dots/page.:page', :controller => 'dummy', :action => 'dots'
      map.connect 'ibocorp/:page', :controller => 'ibocorp',
                                   :requirements => { :page => /\d+/ },
                                   :defaults => { :page => 1 }

      map.connect ':controller/:action/:id'
    end

    assert_equal '/ibocorp', set.generate({:controller => 'ibocorp', :page => 1})
  end

  def test_generate_with_optional_params_recalls_last_request
    set.draw do |map|
      map.connect "blog/", :controller => "blog", :action => "index"

      map.connect "blog/:year/:month/:day",
                  :controller => "blog",
                  :action => "show_date",
                  :requirements => { :year => /(19|20)\d\d/, :month => /[01]?\d/, :day => /[0-3]?\d/ },
                  :day => nil, :month => nil

      map.connect "blog/show/:id", :controller => "blog", :action => "show", :id => /\d+/
      map.connect "blog/:controller/:action/:id"
      map.connect "*anything", :controller => "blog", :action => "unknown_request"
    end

    assert_equal({:controller => "blog", :action => "index"}, set.recognize_path("/blog"))
    assert_equal({:controller => "blog", :action => "show", :id => "123"}, set.recognize_path("/blog/show/123"))
    assert_equal({:controller => "blog", :action => "show_date", :year => "2004"}, set.recognize_path("/blog/2004"))
    assert_equal({:controller => "blog", :action => "show_date", :year => "2004", :month => "12"}, set.recognize_path("/blog/2004/12"))
    assert_equal({:controller => "blog", :action => "show_date", :year => "2004", :month => "12", :day => "25"}, set.recognize_path("/blog/2004/12/25"))
    assert_equal({:controller => "articles", :action => "edit", :id => "123"}, set.recognize_path("/blog/articles/edit/123"))
    assert_equal({:controller => "articles", :action => "show_stats"}, set.recognize_path("/blog/articles/show_stats"))
    assert_equal({:controller => "blog", :action => "unknown_request", :anything => ["blog", "wibble"]}, set.recognize_path("/blog/wibble"))
    assert_equal({:controller => "blog", :action => "unknown_request", :anything => ["junk"]}, set.recognize_path("/junk"))

    last_request = set.recognize_path("/blog/2006/07/28").freeze
    assert_equal({:controller => "blog",  :action => "show_date", :year => "2006", :month => "07", :day => "28"}, last_request)
    assert_equal("/blog/2006/07/25", set.generate({:day => 25}, last_request))
    assert_equal("/blog/2005", set.generate({:year => 2005}, last_request))
    assert_equal("/blog/show/123", set.generate({:action => "show" , :id => 123}, last_request))
    assert_equal("/blog/2006", set.generate({:year => 2006}, last_request))
    assert_equal("/blog/2006", set.generate({:year => 2006, :month => nil}, last_request))
  end

  private
    def assert_uri_equal(expected, actual)
      assert_equal(sort_query_string_params(expected), sort_query_string_params(actual))
    end

    def sort_query_string_params(uri)
      path, qs = uri.split('?')
      qs = qs.split('&').sort.join('&') if qs
      qs ? "#{path}?#{qs}" : path
    end
end

class RackMountIntegrationTests < ActiveSupport::TestCase
  Model = Struct.new(:to_param)

  Mapping = lambda { |map|
    map.namespace :admin do |admin|
      admin.resources :users
    end

    map.namespace 'api' do |api|
      api.root :controller => 'users'
    end

    map.connect 'blog/:year/:month/:day',
                :controller => 'posts',
                :action => 'show_date',
                :requirements => { :year => /(19|20)\d\d/, :month => /[01]?\d/, :day => /[0-3]?\d/},
                :day => nil,
                :month => nil

    map.blog('archive/:year', :controller => 'archive', :action => 'index',
      :defaults => { :year => nil },
      :requirements => { :year => /\d{4}/ }
    )

    map.resources :people
    map.connect 'legacy/people', :controller => 'people', :action => 'index', :legacy => 'true'

    map.connect 'symbols', :controller => :symbols, :action => :show, :name => :as_symbol
    map.connect 'id_default/:id', :controller => 'foo', :action => 'id_default', :id => 1
    map.connect 'get_or_post', :controller => 'foo', :action => 'get_or_post', :conditions => { :method => [:get, :post] }
    map.connect 'optional/:optional', :controller => 'posts', :action => 'index'
    map.project 'projects/:project_id', :controller => 'project'
    map.connect 'clients', :controller => 'projects', :action => 'index'

    map.connect 'ignorecase/geocode/:postalcode', :controller => 'geocode',
                  :action => 'show', :postalcode => /hx\d\d-\d[a-z]{2}/i
    map.geocode 'extended/geocode/:postalcode', :controller => 'geocode',
                  :action => 'show',:requirements => {
                  :postalcode => /# Postcode format
                                  \d{5} #Prefix
                                  (-\d{4})? #Suffix
                                  /x
                  }

    map.connect '', :controller => 'news', :format => nil
    map.connect 'news.:format', :controller => 'news'

    map.connect 'comment/:id/:action', :controller => 'comments', :action => 'show'
    map.connect 'ws/:controller/:action/:id', :ws => true
    map.connect 'account/:action', :controller => :account, :action => :subscription
    map.connect 'pages/:page_id/:controller/:action/:id'
    map.connect ':controller/ping', :action => 'ping'
    map.connect ':controller/:action/:id'
  }

  def setup
    @routes = ActionController::Routing::RouteSet.new
    @routes.draw(&Mapping)
  end

  def test_add_route
    @routes.clear!

    assert_raise(ActionController::RoutingError) do
      @routes.draw do |map|
        map.path 'file/*path', :controller => 'content', :action => 'show_file', :path => %w(fake default)
        map.connect ':controller/:action/:id'
      end
    end
  end

  def test_recognize_path
    assert_equal({:controller => 'admin/users', :action => 'index'}, @routes.recognize_path('/admin/users', :method => :get))
    assert_equal({:controller => 'admin/users', :action => 'create'}, @routes.recognize_path('/admin/users', :method => :post))
    assert_equal({:controller => 'admin/users', :action => 'new'}, @routes.recognize_path('/admin/users/new', :method => :get))
    assert_equal({:controller => 'admin/users', :action => 'show', :id => '1'}, @routes.recognize_path('/admin/users/1', :method => :get))
    assert_equal({:controller => 'admin/users', :action => 'update', :id => '1'}, @routes.recognize_path('/admin/users/1', :method => :put))
    assert_equal({:controller => 'admin/users', :action => 'destroy', :id => '1'}, @routes.recognize_path('/admin/users/1', :method => :delete))
    assert_equal({:controller => 'admin/users', :action => 'edit', :id => '1'}, @routes.recognize_path('/admin/users/1/edit', :method => :get))

    assert_equal({:controller => 'admin/posts', :action => 'index'}, @routes.recognize_path('/admin/posts', :method => :get))
    assert_equal({:controller => 'admin/posts', :action => 'new'}, @routes.recognize_path('/admin/posts/new', :method => :get))

    assert_equal({:controller => 'api/users', :action => 'index'}, @routes.recognize_path('/api', :method => :get))
    assert_equal({:controller => 'api/users', :action => 'index'}, @routes.recognize_path('/api/', :method => :get))

    assert_equal({:controller => 'posts', :action => 'show_date', :year => '2009'}, @routes.recognize_path('/blog/2009', :method => :get))
    assert_equal({:controller => 'posts', :action => 'show_date', :year => '2009', :month => '01'}, @routes.recognize_path('/blog/2009/01', :method => :get))
    assert_equal({:controller => 'posts', :action => 'show_date', :year => '2009', :month => '01', :day => '01'}, @routes.recognize_path('/blog/2009/01/01', :method => :get))

    assert_equal({:controller => 'archive', :action => 'index', :year => '2010'}, @routes.recognize_path('/archive/2010'))
    assert_equal({:controller => 'archive', :action => 'index'}, @routes.recognize_path('/archive'))

    assert_equal({:controller => 'people', :action => 'index'}, @routes.recognize_path('/people', :method => :get))
    assert_equal({:controller => 'people', :action => 'index', :format => 'xml'}, @routes.recognize_path('/people.xml', :method => :get))
    assert_equal({:controller => 'people', :action => 'create'}, @routes.recognize_path('/people', :method => :post))
    assert_equal({:controller => 'people', :action => 'new'}, @routes.recognize_path('/people/new', :method => :get))
    assert_equal({:controller => 'people', :action => 'show', :id => '1'}, @routes.recognize_path('/people/1', :method => :get))
    assert_equal({:controller => 'people', :action => 'show', :id => '1', :format => 'xml'}, @routes.recognize_path('/people/1.xml', :method => :get))
    assert_equal({:controller => 'people', :action => 'update', :id => '1'}, @routes.recognize_path('/people/1', :method => :put))
    assert_equal({:controller => 'people', :action => 'destroy', :id => '1'}, @routes.recognize_path('/people/1', :method => :delete))
    assert_equal({:controller => 'people', :action => 'edit', :id => '1'}, @routes.recognize_path('/people/1/edit', :method => :get))
    assert_equal({:controller => 'people', :action => 'edit', :id => '1', :format => 'xml'}, @routes.recognize_path('/people/1/edit.xml', :method => :get))

    assert_equal({:controller => 'symbols', :action => 'show', :name => :as_symbol}, @routes.recognize_path('/symbols'))
    assert_equal({:controller => 'foo', :action => 'id_default', :id => '1'}, @routes.recognize_path('/id_default/1'))
    assert_equal({:controller => 'foo', :action => 'id_default', :id => '2'}, @routes.recognize_path('/id_default/2'))
    assert_equal({:controller => 'foo', :action => 'id_default', :id => '1'}, @routes.recognize_path('/id_default'))
    assert_equal({:controller => 'foo', :action => 'get_or_post'}, @routes.recognize_path('/get_or_post', :method => :get))
    assert_equal({:controller => 'foo', :action => 'get_or_post'}, @routes.recognize_path('/get_or_post', :method => :post))
    assert_raise(ActionController::ActionControllerError) { @routes.recognize_path('/get_or_post', :method => :put) }
    assert_raise(ActionController::ActionControllerError) { @routes.recognize_path('/get_or_post', :method => :delete) }

    assert_equal({:controller => 'posts', :action => 'index', :optional => 'bar'}, @routes.recognize_path('/optional/bar'))
    assert_raise(ActionController::ActionControllerError) { @routes.recognize_path('/optional') }

    assert_equal({:controller => 'posts', :action => 'show', :id => '1', :ws => true}, @routes.recognize_path('/ws/posts/show/1', :method => :get))
    assert_equal({:controller => 'posts', :action => 'list', :ws => true}, @routes.recognize_path('/ws/posts/list', :method => :get))
    assert_equal({:controller => 'posts', :action => 'index', :ws => true}, @routes.recognize_path('/ws/posts', :method => :get))

    assert_equal({:controller => 'account', :action => 'subscription'}, @routes.recognize_path('/account', :method => :get))
    assert_equal({:controller => 'account', :action => 'subscription'}, @routes.recognize_path('/account/subscription', :method => :get))
    assert_equal({:controller => 'account', :action => 'billing'}, @routes.recognize_path('/account/billing', :method => :get))

    assert_equal({:page_id => '1', :controller => 'notes', :action => 'index'}, @routes.recognize_path('/pages/1/notes', :method => :get))
    assert_equal({:page_id => '1', :controller => 'notes', :action => 'list'}, @routes.recognize_path('/pages/1/notes/list', :method => :get))
    assert_equal({:page_id => '1', :controller => 'notes', :action => 'show', :id => '2'}, @routes.recognize_path('/pages/1/notes/show/2', :method => :get))

    assert_equal({:controller => 'posts', :action => 'ping'}, @routes.recognize_path('/posts/ping', :method => :get))
    assert_equal({:controller => 'posts', :action => 'index'}, @routes.recognize_path('/posts', :method => :get))
    assert_equal({:controller => 'posts', :action => 'index'}, @routes.recognize_path('/posts/index', :method => :get))
    assert_equal({:controller => 'posts', :action => 'show'}, @routes.recognize_path('/posts/show', :method => :get))
    assert_equal({:controller => 'posts', :action => 'show', :id => '1'}, @routes.recognize_path('/posts/show/1', :method => :get))
    assert_equal({:controller => 'posts', :action => 'create'}, @routes.recognize_path('/posts/create', :method => :post))

    assert_equal({:controller => 'geocode', :action => 'show', :postalcode => 'hx12-1az'}, @routes.recognize_path('/ignorecase/geocode/hx12-1az'))
    assert_equal({:controller => 'geocode', :action => 'show', :postalcode => 'hx12-1AZ'}, @routes.recognize_path('/ignorecase/geocode/hx12-1AZ'))
    assert_equal({:controller => 'geocode', :action => 'show', :postalcode => '12345-1234'}, @routes.recognize_path('/extended/geocode/12345-1234'))
    assert_equal({:controller => 'geocode', :action => 'show', :postalcode => '12345'}, @routes.recognize_path('/extended/geocode/12345'))

    assert_equal({:controller => 'news', :action => 'index', :format => nil}, @routes.recognize_path('/', :method => :get))
    assert_equal({:controller => 'news', :action => 'index', :format => 'rss'}, @routes.recognize_path('/news.rss', :method => :get))

    assert_raise(ActionController::RoutingError) { @routes.recognize_path('/none', :method => :get) }
  end

  def test_generate
    assert_equal '/admin/users', @routes.generate(:use_route => 'admin_users')
    assert_equal '/admin/users', @routes.generate(:controller => 'admin/users')
    assert_equal '/admin/users', @routes.generate(:controller => 'admin/users', :action => 'index')
    assert_equal '/admin/users', @routes.generate({:action => 'index'}, {:controller => 'admin/users'})
    assert_equal '/admin/users', @routes.generate({:controller => 'users', :action => 'index'}, {:controller => 'admin/accounts'})
    assert_equal '/people', @routes.generate({:controller => '/people', :action => 'index'}, {:controller => 'admin/accounts'})

    assert_equal '/admin/posts', @routes.generate({:controller => 'admin/posts'})
    assert_equal '/admin/posts/new', @routes.generate({:controller => 'admin/posts', :action => 'new'})

    assert_equal '/blog/2009', @routes.generate(:controller => 'posts', :action => 'show_date', :year => 2009)
    assert_equal '/blog/2009/1', @routes.generate(:controller => 'posts', :action => 'show_date', :year => 2009, :month => 1)
    assert_equal '/blog/2009/1/1', @routes.generate(:controller => 'posts', :action => 'show_date', :year => 2009, :month => 1, :day => 1)

    assert_equal '/archive/2010', @routes.generate(:controller => 'archive', :action => 'index', :year => '2010')
    assert_equal '/archive', @routes.generate(:controller => 'archive', :action => 'index')
    assert_equal '/archive?year=january', @routes.generate(:controller => 'archive', :action => 'index', :year => 'january')

    assert_equal '/people', @routes.generate(:use_route => 'people')
    assert_equal '/people', @routes.generate(:use_route => 'people', :controller => 'people', :action => 'index')
    assert_equal '/people.xml', @routes.generate(:use_route => 'people', :controller => 'people', :action => 'index', :format => 'xml')
    assert_equal '/people', @routes.generate({:use_route => 'people', :controller => 'people', :action => 'index'}, {:controller => 'people', :action => 'index'})
    assert_equal '/people', @routes.generate(:controller => 'people')
    assert_equal '/people', @routes.generate(:controller => 'people', :action => 'index')
    assert_equal '/people', @routes.generate({:action => 'index'}, {:controller => 'people'})
    assert_equal '/people', @routes.generate({:action => 'index'}, {:controller => 'people', :action => 'show', :id => '1'})
    assert_equal '/people', @routes.generate({:controller => 'people', :action => 'index'}, {:controller => 'people', :action => 'show', :id => '1'})
    assert_equal '/people', @routes.generate({}, {:controller => 'people', :action => 'index'})
    assert_equal '/people/1', @routes.generate({:controller => 'people', :action => 'show'}, {:controller => 'people', :action => 'show', :id => '1'})
    assert_equal '/people/new', @routes.generate(:use_route => 'new_person')
    assert_equal '/people/new', @routes.generate(:controller => 'people', :action => 'new')
    assert_equal '/people/1', @routes.generate(:use_route => 'person', :id => '1')
    assert_equal '/people/1', @routes.generate(:controller => 'people', :action => 'show', :id => '1')
    assert_equal '/people/1.xml', @routes.generate(:controller => 'people', :action => 'show', :id => '1', :format => 'xml')
    assert_equal '/people/1', @routes.generate(:controller => 'people', :action => 'show', :id => 1)
    assert_equal '/people/1', @routes.generate(:controller => 'people', :action => 'show', :id => Model.new('1'))
    assert_equal '/people/1', @routes.generate({:action => 'show', :id => '1'}, {:controller => 'people', :action => 'index'})
    assert_equal '/people/1', @routes.generate({:action => 'show', :id => 1}, {:controller => 'people', :action => 'show', :id => '1'})
    # assert_equal '/people', @routes.generate({:controller => 'people', :action => 'index'}, {:controller => 'people', :action => 'index', :id => '1'})
    assert_equal '/people', @routes.generate({:controller => 'people', :action => 'index'}, {:controller => 'people', :action => 'show', :id => '1'})
    assert_equal '/people/1', @routes.generate({}, {:controller => 'people', :action => 'show', :id => '1'})
    assert_equal '/people/1', @routes.generate({:controller => 'people', :action => 'show'}, {:controller => 'people', :action => 'index', :id => '1'})
    assert_equal '/people/1/edit', @routes.generate(:controller => 'people', :action => 'edit', :id => '1')
    assert_equal '/people/1/edit.xml', @routes.generate(:controller => 'people', :action => 'edit', :id => '1', :format => 'xml')
    assert_equal '/people/1/edit', @routes.generate(:use_route => 'edit_person', :id => '1')
    assert_equal '/people/1?legacy=true', @routes.generate(:controller => 'people', :action => 'show', :id => '1', :legacy => 'true')
    assert_equal '/people?legacy=true', @routes.generate(:controller => 'people', :action => 'index', :legacy => 'true')

    assert_equal '/id_default/2', @routes.generate(:controller => 'foo', :action => 'id_default', :id => '2')
    assert_equal '/id_default', @routes.generate(:controller => 'foo', :action => 'id_default', :id => '1')
    assert_equal '/id_default', @routes.generate(:controller => 'foo', :action => 'id_default', :id => 1)
    assert_equal '/id_default', @routes.generate(:controller => 'foo', :action => 'id_default')
    assert_equal '/optional/bar', @routes.generate(:controller => 'posts', :action => 'index', :optional => 'bar')
    assert_equal '/posts', @routes.generate(:controller => 'posts', :action => 'index')

    assert_equal '/project', @routes.generate({:controller => 'project', :action => 'index'})
    assert_equal '/projects/1', @routes.generate({:controller => 'project', :action => 'index', :project_id => '1'})
    assert_equal '/projects/1', @routes.generate({:controller => 'project', :action => 'index'}, {:project_id => '1'})
    assert_raise(ActionController::RoutingError) { @routes.generate({:use_route => 'project', :controller => 'project', :action => 'index'}) }
    assert_equal '/projects/1', @routes.generate({:use_route => 'project', :controller => 'project', :action => 'index', :project_id => '1'})
    assert_equal '/projects/1', @routes.generate({:use_route => 'project', :controller => 'project', :action => 'index'}, {:project_id => '1'})

    assert_equal '/clients', @routes.generate(:controller => 'projects', :action => 'index')
    assert_equal '/clients?project_id=1', @routes.generate(:controller => 'projects', :action => 'index', :project_id => '1')
    assert_equal '/clients', @routes.generate({:controller => 'projects', :action => 'index'}, {:project_id => '1'})
    assert_equal '/clients', @routes.generate({:action => 'index'}, {:controller => 'projects', :action => 'index', :project_id => '1'})

    assert_equal '/comment/20', @routes.generate({:id => 20}, {:controller => 'comments', :action => 'show'})
    assert_equal '/comment/20', @routes.generate(:controller => 'comments', :id => 20, :action => 'show')
    assert_equal '/comments/boo', @routes.generate(:controller => 'comments', :action => 'boo')

    assert_equal '/ws/posts/show/1', @routes.generate(:controller => 'posts', :action => 'show', :id => '1', :ws => true)
    assert_equal '/ws/posts', @routes.generate(:controller => 'posts', :action => 'index', :ws => true)

    assert_equal '/account', @routes.generate(:controller => 'account', :action => 'subscription')
    assert_equal '/account/billing', @routes.generate(:controller => 'account', :action => 'billing')

    assert_equal '/pages/1/notes/show/1', @routes.generate(:page_id => '1', :controller => 'notes', :action => 'show', :id => '1')
    assert_equal '/pages/1/notes/list', @routes.generate(:page_id => '1', :controller => 'notes', :action => 'list')
    assert_equal '/pages/1/notes', @routes.generate(:page_id => '1', :controller => 'notes', :action => 'index')
    assert_equal '/pages/1/notes', @routes.generate(:page_id => '1', :controller => 'notes')
    assert_equal '/notes', @routes.generate(:page_id => nil, :controller => 'notes')
    assert_equal '/notes', @routes.generate(:controller => 'notes')
    assert_equal '/notes/print', @routes.generate(:controller => 'notes', :action => 'print')
    assert_equal '/notes/print', @routes.generate({}, {:controller => 'notes', :action => 'print'})

    assert_equal '/notes/index/1', @routes.generate({:controller => 'notes'}, {:controller => 'notes', :id => '1'})
    assert_equal '/notes/index/1', @routes.generate({:controller => 'notes'}, {:controller => 'notes', :id => '1', :foo => 'bar'})
    assert_equal '/notes/index/1', @routes.generate({:controller => 'notes'}, {:controller => 'notes', :id => '1'})
    assert_equal '/notes/index/1', @routes.generate({:action => 'index'}, {:controller => 'notes', :id => '1'})
    assert_equal '/notes/index/1', @routes.generate({}, {:controller => 'notes', :id => '1'})
    assert_equal '/notes/show/1', @routes.generate({}, {:controller => 'notes', :action => 'show', :id => '1'})
    assert_equal '/notes/index/1', @routes.generate({:controller => 'notes', :id => '1'}, {:foo => 'bar'})
    assert_equal '/posts', @routes.generate({:controller => 'posts'}, {:controller => 'notes', :action => 'show', :id => '1'})
    assert_equal '/notes/list', @routes.generate({:action => 'list'}, {:controller => 'notes', :action => 'show', :id => '1'})

    assert_equal '/posts/ping', @routes.generate(:controller => 'posts', :action => 'ping')
    assert_equal '/posts/show/1', @routes.generate(:controller => 'posts', :action => 'show', :id => '1')
    assert_equal '/posts', @routes.generate(:controller => 'posts')
    assert_equal '/posts', @routes.generate(:controller => 'posts', :action => 'index')
    assert_equal '/posts', @routes.generate({:controller => 'posts'}, {:controller => 'posts', :action => 'index'})
    assert_equal '/posts/create', @routes.generate({:action => 'create'}, {:controller => 'posts'})
    assert_equal '/posts?foo=bar', @routes.generate(:controller => 'posts', :foo => 'bar')
    assert_equal '/posts?foo[]=bar&foo[]=baz', @routes.generate(:controller => 'posts', :foo => ['bar', 'baz'])
    assert_equal '/posts?page=2', @routes.generate(:controller => 'posts', :page => 2)
    assert_equal '/posts?q[foo][a]=b', @routes.generate(:controller => 'posts', :q => { :foo => { :a => 'b'}})

    assert_equal '/', @routes.generate(:controller => 'news', :action => 'index')
    assert_equal '/', @routes.generate(:controller => 'news', :action => 'index', :format => nil)
    assert_equal '/news.rss', @routes.generate(:controller => 'news', :action => 'index', :format => 'rss')


    assert_raise(ActionController::RoutingError) { @routes.generate({:action => 'index'}) }
  end

  def test_generate_extras
    assert_equal ['/people', []], @routes.generate_extras(:controller => 'people')
    assert_equal ['/people', [:foo]], @routes.generate_extras(:controller => 'people', :foo => 'bar')
    assert_equal ['/people', []], @routes.generate_extras(:controller => 'people', :action => 'index')
    assert_equal ['/people', [:foo]], @routes.generate_extras(:controller => 'people', :action => 'index', :foo => 'bar')
    assert_equal ['/people/new', []], @routes.generate_extras(:controller => 'people', :action => 'new')
    assert_equal ['/people/new', [:foo]], @routes.generate_extras(:controller => 'people', :action => 'new', :foo => 'bar')
    assert_equal ['/people/1', []], @routes.generate_extras(:controller => 'people', :action => 'show', :id => '1')
    assert_equal ['/people/1', [:bar, :foo]], sort_extras!(@routes.generate_extras(:controller => 'people', :action => 'show', :id => '1', :foo => '2', :bar => '3'))
    assert_equal ['/people', [:person]], @routes.generate_extras(:controller => 'people', :action => 'create', :person => { :first_name => 'Josh', :last_name => 'Peek' })
    assert_equal ['/people', [:people]], @routes.generate_extras(:controller => 'people', :action => 'create', :people => ['Josh', 'Dave'])

    assert_equal ['/posts/show/1', []], @routes.generate_extras(:controller => 'posts', :action => 'show', :id => '1')
    assert_equal ['/posts/show/1', [:bar, :foo]], sort_extras!(@routes.generate_extras(:controller => 'posts', :action => 'show', :id => '1', :foo => '2', :bar => '3'))
    assert_equal ['/posts', []], @routes.generate_extras(:controller => 'posts', :action => 'index')
    assert_equal ['/posts', [:foo]], @routes.generate_extras(:controller => 'posts', :action => 'index', :foo => 'bar')
  end

  def test_extras
    params = {:controller => 'people'}
    assert_equal [], @routes.extra_keys(params)
    assert_equal({:controller => 'people'}, params)

    params = {:controller => 'people', :foo => 'bar'}
    assert_equal [:foo], @routes.extra_keys(params)
    assert_equal({:controller => 'people', :foo => 'bar'}, params)

    params = {:controller => 'people', :action => 'create', :person => { :name => 'Josh'}}
    assert_equal [:person], @routes.extra_keys(params)
    assert_equal({:controller => 'people', :action => 'create', :person => { :name => 'Josh'}}, params)
  end

  private
    def sort_extras!(extras)
      if extras.length == 2
        extras[1].sort! { |a, b| a.to_s <=> b.to_s }
      end
      extras
    end

    def assert_raise(e)
      result = yield
      flunk "Did not raise #{e}, but returned #{result.inspect}"
    rescue e
      assert true
    end
end
