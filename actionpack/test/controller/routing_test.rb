# encoding: utf-8
require 'abstract_unit'
require 'controller/fake_controllers'
require 'active_support/core_ext/object/with_options'

class MilestonesController < ActionController::Base
  def index() head :ok end
  alias_method :show, :index
  def rescue_action(e) raise e end
end

ROUTING = ActionDispatch::Routing

# See RFC 3986, section 3.3 for allowed path characters.
class UriReservedCharactersRoutingTest < Test::Unit::TestCase
  include RoutingTestHelpers

  def setup
    @set = ActionDispatch::Routing::RouteSet.new
    @set.draw do
      match ':controller/:action/:variable/*additional'
    end

    safe, unsafe = %w(: @ & = + $ , ;), %w(^ ? # [ ])
    hex = unsafe.map { |char| '%' + char.unpack('H2').first.upcase }

    @segment = "#{safe.join}#{unsafe.join}".freeze
    @escaped = "#{safe.join}#{hex.join}".freeze
  end

  def test_route_generation_escapes_unsafe_path_characters
    assert_equal "/content/act#{@escaped}ion/var#{@escaped}iable/add#{@escaped}itional-1/add#{@escaped}itional-2",
      url_for(@set, {
        :controller => "content",
        :action => "act#{@segment}ion",
        :variable => "var#{@segment}iable",
        :additional => ["add#{@segment}itional-1", "add#{@segment}itional-2"]
      })
  end

  def test_route_recognition_unescapes_path_components
    options = { :controller => "content",
                :action => "act#{@segment}ion",
                :variable => "var#{@segment}iable",
                :additional => "add#{@segment}itional-1/add#{@segment}itional-2" }
    assert_equal options, @set.recognize_path("/content/act#{@escaped}ion/var#{@escaped}iable/add#{@escaped}itional-1/add#{@escaped}itional-2")
  end

  def test_route_generation_allows_passing_non_string_values_to_generated_helper
    assert_equal "/content/action/variable/1/2",
      url_for(@set, {
        :controller => "content",
        :action => "action",
        :variable => "variable",
        :additional => [1, 2]
      })
  end
end

class MockController
  def self.build(helpers, additional_options = {})
    Class.new do
      define_method :url_for do |options|
        options[:protocol] ||= "http"
        options[:host] ||= "test.host"

        super(options.merge(additional_options))
      end

      include helpers
    end
  end
end

class LegacyRouteSetTests < Test::Unit::TestCase
  include RoutingTestHelpers

  attr_reader :rs

  def setup
    @rs       = ::ActionDispatch::Routing::RouteSet.new
    @response = nil
  end

  def get(uri_or_host, path = nil, port = nil)
    host = uri_or_host.host unless path
    path ||= uri_or_host.path

    params = {'PATH_INFO'      => path,
              'REQUEST_METHOD' => 'GET',
              'HTTP_HOST'      => host}

    @rs.call(params)[2].join
  end

  def test_symbols_with_dashes
    rs.draw do
      match '/:artist/:song-omg', :to => lambda { |env|
        resp = JSON.dump env[ActionDispatch::Routing::RouteSet::PARAMETERS_KEY]
        [200, {}, [resp]]
      }
    end

    hash = JSON.load get(URI('http://example.org/journey/faithfully-omg'))
    assert_equal({"artist"=>"journey", "song"=>"faithfully"}, hash)
  end

  def test_id_with_dash
    rs.draw do
      match '/journey/:id', :to => lambda { |env|
        resp = JSON.dump env[ActionDispatch::Routing::RouteSet::PARAMETERS_KEY]
        [200, {}, [resp]]
      }
    end

    hash = JSON.load get(URI('http://example.org/journey/faithfully-omg'))
    assert_equal({"id"=>"faithfully-omg"}, hash)
  end

  def test_dash_with_custom_regexp
    rs.draw do
      match '/:artist/:song-omg', :constraints => { :song => /\d+/ }, :to => lambda { |env|
        resp = JSON.dump env[ActionDispatch::Routing::RouteSet::PARAMETERS_KEY]
        [200, {}, [resp]]
      }
    end

    hash = JSON.load get(URI('http://example.org/journey/123-omg'))
    assert_equal({"artist"=>"journey", "song"=>"123"}, hash)
    assert_equal 'Not Found', get(URI('http://example.org/journey/faithfully-omg'))
  end

  def test_pre_dash
    rs.draw do
      match '/:artist/omg-:song', :to => lambda { |env|
        resp = JSON.dump env[ActionDispatch::Routing::RouteSet::PARAMETERS_KEY]
        [200, {}, [resp]]
      }
    end

    hash = JSON.load get(URI('http://example.org/journey/omg-faithfully'))
    assert_equal({"artist"=>"journey", "song"=>"faithfully"}, hash)
  end

  def test_pre_dash_with_custom_regexp
    rs.draw do
      match '/:artist/omg-:song', :constraints => { :song => /\d+/ }, :to => lambda { |env|
        resp = JSON.dump env[ActionDispatch::Routing::RouteSet::PARAMETERS_KEY]
        [200, {}, [resp]]
      }
    end

    hash = JSON.load get(URI('http://example.org/journey/omg-123'))
    assert_equal({"artist"=>"journey", "song"=>"123"}, hash)
    assert_equal 'Not Found', get(URI('http://example.org/journey/omg-faithfully'))
  end

  def test_star_paths_are_greedy
    rs.draw do
      match "/*path", :to => lambda { |env|
        x = env["action_dispatch.request.path_parameters"][:path]
        [200, {}, [x]]
      }, :format => false
    end

    u = URI('http://example.org/foo/bar.html')
    assert_equal u.path.sub(/^\//, ''), get(u)
  end

  def test_star_paths_are_greedy_but_not_too_much
    rs.draw do
      match "/*path", :to => lambda { |env|
        x = JSON.dump env["action_dispatch.request.path_parameters"]
        [200, {}, [x]]
      }
    end

    expected = { "path" => "foo/bar", "format" => "html" }
    u = URI('http://example.org/foo/bar.html')
    assert_equal expected, JSON.parse(get(u))
  end

  def test_optional_star_paths_are_greedy
    rs.draw do
      match "/(*filters)", :to => lambda { |env|
        x = env["action_dispatch.request.path_parameters"][:filters]
        [200, {}, [x]]
      }, :format => false
    end

    u = URI('http://example.org/ne_27.065938,-80.6092/sw_25.489856,-82.542794')
    assert_equal u.path.sub(/^\//, ''), get(u)
  end

  def test_optional_star_paths_are_greedy_but_not_too_much
    rs.draw do
      match "/(*filters)", :to => lambda { |env|
        x = JSON.dump env["action_dispatch.request.path_parameters"]
        [200, {}, [x]]
      }
    end

    expected = { "filters" => "ne_27.065938,-80.6092/sw_25.489856,-82",
                 "format"  => "542794" }
    u = URI('http://example.org/ne_27.065938,-80.6092/sw_25.489856,-82.542794')
    assert_equal expected, JSON.parse(get(u))
  end

  def test_regexp_precidence
    @rs.draw do
      match '/whois/:domain', :constraints => {
        :domain => /\w+\.[\w\.]+/ },
        :to     => lambda { |env| [200, {}, %w{regexp}] }

      match '/whois/:id', :to => lambda { |env| [200, {}, %w{id}] }
    end

    assert_equal 'regexp', get(URI('http://example.org/whois/example.org'))
    assert_equal 'id', get(URI('http://example.org/whois/123'))
  end

  def test_class_and_lambda_constraints
    subdomain = Class.new {
      def matches? request
        request.subdomain.present? and request.subdomain != 'clients'
      end
    }

    @rs.draw do
      match '/', :constraints => subdomain.new,
                 :to          => lambda { |env| [200, {}, %w{default}] }
      match '/', :constraints => { :subdomain => 'clients' },
                 :to          => lambda { |env| [200, {}, %w{clients}] }
    end

    assert_equal 'default', get(URI('http://www.example.org/'))
    assert_equal 'clients', get(URI('http://clients.example.org/'))
  end

  def test_lambda_constraints
    @rs.draw do
      match '/', :constraints => lambda { |req|
        req.subdomain.present? and req.subdomain != "clients" },
                 :to          => lambda { |env| [200, {}, %w{default}] }

      match '/', :constraints => lambda { |req|
        req.subdomain.present? && req.subdomain == "clients" },
                 :to          => lambda { |env| [200, {}, %w{clients}] }
    end

    assert_equal 'default', get(URI('http://www.example.org/'))
    assert_equal 'clients', get(URI('http://clients.example.org/'))
  end

  def test_empty_string_match
    rs.draw do
      get '/:username', :constraints => { :username => /[^\/]+/ },
                       :to => lambda { |e| [200, {}, ['foo']] }
    end
    assert_equal 'Not Found', get(URI('http://example.org/'))
    assert_equal 'foo', get(URI('http://example.org/hello'))
  end

  def test_non_greedy_glob_regexp
    params = nil
    rs.draw do
      get '/posts/:id(/*filters)', :constraints => { :filters => /.+?/ },
        :to => lambda { |e|
        params = e["action_dispatch.request.path_parameters"]
        [200, {}, ['foo']]
      }
    end
    assert_equal 'foo', get(URI('http://example.org/posts/1/foo.js'))
    assert_equal({:id=>"1", :filters=>"foo", :format=>"js"}, params)
  end

  def test_draw_with_block_arity_one_raises
    assert_raise(RuntimeError) do
      @rs.draw { |map| map.match '/:controller(/:action(/:id))' }
    end
  end

  def test_specific_controller_action_failure
    @rs.draw do
      mount lambda {} => "/foo"
    end

    assert_raises(ActionController::RoutingError) do
      url_for(@rs, :controller => "omg", :action => "lol")
    end
  end

  def test_default_setup
    @rs.draw { match '/:controller(/:action(/:id))' }
    assert_equal({:controller => "content", :action => 'index'}, rs.recognize_path("/content"))
    assert_equal({:controller => "content", :action => 'list'},  rs.recognize_path("/content/list"))
    assert_equal({:controller => "content", :action => 'show', :id => '10'}, rs.recognize_path("/content/show/10"))

    assert_equal({:controller => "admin/user", :action => 'show', :id => '10'}, rs.recognize_path("/admin/user/show/10"))

    assert_equal '/admin/user/show/10', url_for(rs, { :controller => 'admin/user', :action => 'show', :id => 10 })

    assert_equal '/admin/user/show',    url_for(rs, { :action => 'show' }, { :controller => 'admin/user', :action => 'list', :id => '10' })
    assert_equal '/admin/user/list/10', url_for(rs, {}, { :controller => 'admin/user', :action => 'list', :id => '10' })

    assert_equal '/admin/stuff', url_for(rs, { :controller => 'stuff' }, { :controller => 'admin/user', :action => 'list', :id => '10' })
    assert_equal '/stuff',       url_for(rs, { :controller => '/stuff' }, { :controller => 'admin/user', :action => 'list', :id => '10' })
  end

  def test_ignores_leading_slash
    @rs.clear!
    @rs.draw { match '/:controller(/:action(/:id))'}
    test_default_setup
  end

  def test_time_recognition
    # We create many routes to make situation more realistic
    @rs = ::ActionDispatch::Routing::RouteSet.new
    @rs.draw {
      root :to => "search#new", :as => "frontpage"
      resources :videos do
        resources :comments
        resource  :file,      :controller => 'video_file'
        resource  :share,     :controller => 'video_shares'
        resource  :abuse,     :controller => 'video_abuses'
      end
      resources :abuses, :controller => 'video_abuses'
      resources :video_uploads
      resources :video_visits

      resources :users do
        resource  :settings
        resources :videos
      end
      resources :channels do
        resources :videos, :controller => 'channel_videos'
      end
      resource  :session
      resource  :lost_password
      match 'search' => 'search#index', :as => 'search'
      resources :pages
      match ':controller/:action/:id'
    }
  end

  def test_route_with_colon_first
    rs.draw do
      match '/:controller/:action/:id', :action => 'index', :id => nil
      match ':url', :controller => 'tiny_url', :action => 'translate'
    end
  end

  def test_route_with_regexp_for_controller
    rs.draw do
      match ':controller/:admintoken(/:action(/:id))', :controller => /admin\/.+/
      match '/:controller(/:action(/:id))'
    end

    assert_equal({:controller => "admin/user", :admintoken => "foo", :action => "index"},
        rs.recognize_path("/admin/user/foo"))
    assert_equal({:controller => "content", :action => "foo"},
        rs.recognize_path("/content/foo"))

    assert_equal '/admin/user/foo', url_for(rs, { :controller => "admin/user", :admintoken => "foo", :action => "index" })
    assert_equal '/content/foo',    url_for(rs, { :controller => "content", :action => "foo" })
  end

  def test_route_with_regexp_and_captures_for_controller
    rs.draw do
      match '/:controller(/:action(/:id))', :controller => /admin\/(accounts|users)/
    end
    assert_equal({:controller => "admin/accounts", :action => "index"}, rs.recognize_path("/admin/accounts"))
    assert_equal({:controller => "admin/users", :action => "index"}, rs.recognize_path("/admin/users"))
    assert_raise(ActionController::RoutingError) { rs.recognize_path("/admin/products") }
  end

  def test_route_with_regexp_and_dot
    rs.draw do
      match ':controller/:action/:file',
                :controller => /admin|user/,
                :action => /upload|download/,
                :defaults => {:file => nil},
                :constraints => {:file => %r{[^/]+(\.[^/]+)?}}
    end
    # Without a file extension
    assert_equal '/user/download/file',
      url_for(rs, { :controller => "user", :action => "download", :file => "file" })

    assert_equal({:controller => "user", :action => "download", :file => "file"},
      rs.recognize_path("/user/download/file"))

    # Now, let's try a file with an extension, really a dot (.)
    assert_equal '/user/download/file.jpg',
      url_for(rs, { :controller => "user", :action => "download", :file => "file.jpg" })

    assert_equal({:controller => "user", :action => "download", :file => "file.jpg"},
      rs.recognize_path("/user/download/file.jpg"))
  end

  def test_basic_named_route
    rs.draw do
      root :to => 'content#list', :as => 'home'
    end
    assert_equal("http://test.host/", setup_for_named_route.send(:home_url))
  end

  def test_named_route_with_option
    rs.draw do
      match 'page/:title' => 'content#show_page', :as => 'page'
    end

    assert_equal("http://test.host/page/new%20stuff",
        setup_for_named_route.send(:page_url, :title => 'new stuff'))
  end

  def test_named_route_with_default
    rs.draw do
      match 'page/:title' => 'content#show_page', :title => 'AboutPage', :as => 'page'
    end

    assert_equal("http://test.host/page/AboutRails",
        setup_for_named_route.send(:page_url, :title => "AboutRails"))
  end

  def test_named_route_with_path_prefix
    rs.draw do
      scope "my" do
        match 'page' => 'content#show_page', :as => 'page'
      end
    end

    assert_equal("http://test.host/my/page",
        setup_for_named_route.send(:page_url))
  end

  def test_named_route_with_blank_path_prefix
    rs.draw do
      scope "" do
        match 'page' => 'content#show_page', :as => 'page'
      end
    end

    assert_equal("http://test.host/page",
        setup_for_named_route.send(:page_url))
  end

  def test_named_route_with_nested_controller
    rs.draw do
      match 'admin/user' => 'admin/user#index', :as => "users"
    end

    assert_equal("http://test.host/admin/user",
        setup_for_named_route.send(:users_url))
  end

  def test_optimised_named_route_with_host
    rs.draw do
      match 'page' => 'content#show_page', :as => 'pages', :host => 'foo.com'
    end
    routes = setup_for_named_route
    routes.expects(:url_for).with({
      :host => 'foo.com',
      :only_path => false,
      :controller => 'content',
      :action => 'show_page',
      :use_route => 'pages'
    }).once
    routes.send(:pages_url)
  end

  def setup_for_named_route(options = {})
    MockController.build(rs.url_helpers, options).new
  end

  def test_named_route_without_hash
    rs.draw do
      match ':controller/:action/:id', :as => 'normal'
    end
  end

  def test_named_route_root
    rs.draw do
      root :to => "hello#index"
    end
    routes = setup_for_named_route
    assert_equal("http://test.host/", routes.send(:root_url))
    assert_equal("/", routes.send(:root_path))
  end

  def test_named_route_root_with_trailing_slash
    rs.draw do
      root :to => "hello#index"
    end

    routes = setup_for_named_route(trailing_slash: true)
    assert_equal("http://test.host/", routes.send(:root_url))
    assert_equal("http://test.host/?foo=bar", routes.send(:root_url, foo: :bar))
  end

  def test_named_route_with_regexps
    rs.draw do
      match 'page/:year/:month/:day/:title' => 'page#show', :as => 'article',
        :year => /\d+/, :month => /\d+/, :day => /\d+/
      match ':controller/:action/:id'
    end

    routes = setup_for_named_route

    assert_equal "http://test.host/page/2005/6/10/hi",
      routes.send(:article_url, :title => 'hi', :day => 10, :year => 2005, :month => 6)
  end

  def test_changing_controller
    @rs.draw { match ':controller/:action/:id' }

    assert_equal '/admin/stuff/show/10',
        url_for(rs, {:controller => 'stuff', :action => 'show', :id => 10},
                    {:controller => 'admin/user', :action => 'index'})
  end

  def test_paths_escaped
    rs.draw do
      match 'file/*path' => 'content#show_file', :as => 'path'
      match ':controller/:action/:id'
    end

    # No + to space in URI escaping, only for query params.
    results = rs.recognize_path "/file/hello+world/how+are+you%3F"
    assert results, "Recognition should have succeeded"
    assert_equal 'hello+world/how+are+you?', results[:path]

    # Use %20 for space instead.
    results = rs.recognize_path "/file/hello%20world/how%20are%20you%3F"
    assert results, "Recognition should have succeeded"
    assert_equal 'hello world/how are you?', results[:path]
  end

  def test_paths_slashes_unescaped_with_ordered_parameters
    rs.draw do
      match '/file/*path' => 'content#index', :as => 'path'
    end

    # No / to %2F in URI, only for query params.
    assert_equal("/file/hello/world", setup_for_named_route.send(:path_path, ['hello', 'world']))
  end

  def test_non_controllers_cannot_be_matched
    rs.draw do
      match ':controller/:action/:id'
    end
    assert_raise(ActionController::RoutingError) { rs.recognize_path("/not_a/show/10") }
  end

  def test_should_list_options_diff_when_routing_constraints_dont_match
    rs.draw do
      match 'post/:id' => 'post#show', :constraints => { :id => /\d+/ }, :as => 'post'
    end
    assert_raise(ActionController::RoutingError) do
      url_for(rs, { :controller => 'post', :action => 'show', :bad_param => "foo", :use_route => "post" })
    end
  end

  def test_dynamic_path_allowed
    rs.draw do
      match '*path' => 'content#show_file'
    end

    assert_equal '/pages/boo',
        url_for(rs, { :controller => 'content', :action => 'show_file', :path => %w(pages boo) })
  end

  def test_dynamic_recall_paths_allowed
    rs.draw do
      match '*path' => 'content#show_file'
    end

    assert_equal '/pages/boo',
        url_for(rs, {}, { :controller => 'content', :action => 'show_file', :path => %w(pages boo) })
  end

  def test_backwards
    rs.draw do
      match 'page/:id(/:action)' => 'pages#show'
      match ':controller(/:action(/:id))'
    end

    assert_equal '/page/20',   url_for(rs, { :id => 20 }, { :controller => 'pages', :action => 'show' })
    assert_equal '/page/20',   url_for(rs, { :controller => 'pages', :id => 20, :action => 'show' })
    assert_equal '/pages/boo', url_for(rs, { :controller => 'pages', :action => 'boo' })
  end

  def test_route_with_fixnum_default
    rs.draw do
      match 'page(/:id)' => 'content#show_page', :id => 1
      match ':controller/:action/:id'
    end

    assert_equal '/page',    url_for(rs, { :controller => 'content', :action => 'show_page' })
    assert_equal '/page',    url_for(rs, { :controller => 'content', :action => 'show_page', :id => 1 })
    assert_equal '/page',    url_for(rs, { :controller => 'content', :action => 'show_page', :id => '1' })
    assert_equal '/page/10', url_for(rs, { :controller => 'content', :action => 'show_page', :id => 10 })

    assert_equal({:controller => "content", :action => 'show_page', :id => 1 }, rs.recognize_path("/page"))
    assert_equal({:controller => "content", :action => 'show_page', :id => '1'}, rs.recognize_path("/page/1"))
    assert_equal({:controller => "content", :action => 'show_page', :id => '10'}, rs.recognize_path("/page/10"))
  end

  # For newer revision
  def test_route_with_text_default
    rs.draw do
      match 'page/:id' => 'content#show_page', :id => 1
      match ':controller/:action/:id'
    end

    assert_equal '/page/foo', url_for(rs, { :controller => 'content', :action => 'show_page', :id => 'foo' })
    assert_equal({ :controller => "content", :action => 'show_page', :id => 'foo' }, rs.recognize_path("/page/foo"))

    token = "\321\202\320\265\320\272\321\201\321\202" # 'text' in Russian
    token.force_encoding(Encoding::BINARY) if token.respond_to?(:force_encoding)
    escaped_token = CGI::escape(token)

    assert_equal '/page/' + escaped_token, url_for(rs, { :controller => 'content', :action => 'show_page', :id => token })
    assert_equal({ :controller => "content", :action => 'show_page', :id => token }, rs.recognize_path("/page/#{escaped_token}"))
  end

  def test_action_expiry
    @rs.draw { match ':controller(/:action(/:id))' }
    assert_equal '/content', url_for(rs, { :controller => 'content' }, { :controller => 'content', :action => 'show' })
  end

  def test_requirement_should_prevent_optional_id
    rs.draw do
      match 'post/:id' => 'post#show', :constraints => {:id => /\d+/}, :as => 'post'
    end

    assert_equal '/post/10', url_for(rs, { :controller => 'post', :action => 'show', :id => 10 })

    assert_raise ActionController::RoutingError do
      url_for(rs, { :controller => 'post', :action => 'show' })
    end
  end

  def test_both_requirement_and_optional
    rs.draw do
      match('test(/:year)' => 'post#show', :as => 'blog',
        :defaults => { :year => nil },
        :constraints => { :year => /\d{4}/ }
      )
      match ':controller/:action/:id'
    end

    assert_equal '/test', url_for(rs, { :controller => 'post', :action => 'show' })
    assert_equal '/test', url_for(rs, { :controller => 'post', :action => 'show', :year => nil })

    assert_equal("http://test.host/test", setup_for_named_route.send(:blog_url))
  end

  def test_set_to_nil_forgets
    rs.draw do
      match 'pages(/:year(/:month(/:day)))' => 'content#list_pages', :month => nil, :day => nil
      match ':controller/:action/:id'
    end

    assert_equal '/pages/2005',
      url_for(rs, { :controller => 'content', :action => 'list_pages', :year => 2005 })
    assert_equal '/pages/2005/6',
      url_for(rs, { :controller => 'content', :action => 'list_pages', :year => 2005, :month => 6 })
    assert_equal '/pages/2005/6/12',
      url_for(rs, { :controller => 'content', :action => 'list_pages', :year => 2005, :month => 6, :day => 12 })

    assert_equal '/pages/2005/6/4',
      url_for(rs, { :day => 4 },   { :controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12' })

    assert_equal '/pages/2005/6',
      url_for(rs, { :day => nil }, { :controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12' })

    assert_equal '/pages/2005',
      url_for(rs, { :day => nil, :month => nil }, { :controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12' })
  end

  def test_root_url_generation_with_controller_and_action
    rs.draw do
      root :to => "content#index"
    end

    assert_equal '/', url_for(rs, { :controller => 'content', :action => 'index' })
    assert_equal '/', url_for(rs, { :controller => 'content' })
  end

  def test_named_root_url_generation_with_controller_and_action
    rs.draw do
       root :to => "content#index", :as => 'home'
    end

    assert_equal '/', url_for(rs, { :controller => 'content', :action => 'index' })
    assert_equal '/', url_for(rs, { :controller => 'content' })

    assert_equal("http://test.host/", setup_for_named_route.send(:home_url))
  end

  def test_named_route_method
    rs.draw do
      match 'categories' => 'content#categories', :as => 'categories'
      match ':controller(/:action(/:id))'
    end

    assert_equal '/categories', url_for(rs, { :controller => 'content', :action => 'categories' })
    assert_equal '/content/hi', url_for(rs, { :controller => 'content', :action => 'hi' })
  end

  def test_named_routes_array
    test_named_route_method
    assert_equal [:categories], rs.named_routes.names
  end

  def test_nil_defaults
    rs.draw do
      match 'journal' => 'content#list_journal',
        :date => nil, :user_id => nil
      match ':controller/:action/:id'
    end

    assert_equal '/journal', url_for(rs, {
      :controller => 'content',
      :action => 'list_journal',
      :date => nil,
      :user_id => nil
    })
  end

  def setup_request_method_routes_for(method)
    rs.draw do
      match '/match' => 'books#get', :via => :get
      match '/match' => 'books#post', :via => :post
      match '/match' => 'books#put', :via => :put
      match '/match' => 'books#delete', :via => :delete
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
    rs.draw do
      match '/match' => 'books#get_or_post', :via => [:get, :post]
      match '/match' => 'books#not_get_or_post'
    end

    params = rs.recognize_path("/match", :method => :post)
    assert_equal 'get_or_post', params[:action]

    params = rs.recognize_path("/match", :method => :put)
    assert_equal 'not_get_or_post', params[:action]
  end

  def test_subpath_recognized
    rs.draw do
      match '/books/:id/edit'    => 'subpath_books#edit'
      match '/items/:id/:action' => 'subpath_books'
      match '/posts/new/:action' => 'subpath_books'
      match '/posts/:id'         => 'subpath_books#show'
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
    rs.draw do
      match '/books/:id/edit'    => 'subpath_books#edit'
      match '/items/:id/:action' => 'subpath_books'
      match '/posts/new/:action' => 'subpath_books'
    end

    assert_equal "/books/7/edit",      url_for(rs, { :controller => "subpath_books", :id => 7, :action => "edit" })
    assert_equal "/items/15/complete", url_for(rs, { :controller => "subpath_books", :id => 15, :action => "complete" })
    assert_equal "/posts/new/preview", url_for(rs, { :controller => "subpath_books", :action => "preview" })
  end

  def test_failed_constraints_raises_exception_with_violated_constraints
    rs.draw do
      match 'foos/:id' => 'foos#show', :as => 'foo_with_requirement', :constraints => { :id => /\d+/ }
    end

    assert_raise(ActionController::RoutingError) do
      setup_for_named_route.send(:foo_with_requirement_url, "I am Against the constraints")
    end
  end

  def test_routes_changed_correctly_after_clear
    rs = ::ActionDispatch::Routing::RouteSet.new
    rs.draw do
      match 'ca' => 'ca#aa'
      match 'cb' => 'cb#ab'
      match 'cc' => 'cc#ac'
      match ':controller/:action/:id'
      match ':controller/:action/:id.:format'
    end

    hash = rs.recognize_path "/cc"

    assert_not_nil hash
    assert_equal %w(cc ac), [hash[:controller], hash[:action]]

    rs.draw do
      match 'cb' => 'cb#ab'
      match 'cc' => 'cc#ac'
      match ':controller/:action/:id'
      match ':controller/:action/:id.:format'
    end

    hash = rs.recognize_path "/cc"

    assert_not_nil hash
    assert_equal %w(cc ac), [hash[:controller], hash[:action]]
  end
end

class RouteSetTest < ActiveSupport::TestCase
  include RoutingTestHelpers

  def set
    @set ||= ROUTING::RouteSet.new
  end

  def request
    @request ||= ActionController::TestRequest.new
  end

  def default_route_set
    @default_route_set ||= begin
      set = ROUTING::RouteSet.new
      set.draw do
        match '/:controller(/:action(/:id))'
      end
      set
    end
  end

  def test_generate_extras
    set.draw { match ':controller/(:action(/:id))' }
    path, extras = set.generate_extras(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal "/foo/bar/15", path
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_extra_keys
    set.draw { match ':controller/:action/:id' }
    extras = set.extra_keys(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_generate_extras_not_first
    set.draw do
      match ':controller/:action/:id.:format'
      match ':controller/:action/:id'
    end
    path, extras = set.generate_extras(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal "/foo/bar/15", path
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_generate_not_first
    set.draw do
      match ':controller/:action/:id.:format'
      match ':controller/:action/:id'
    end
    assert_equal "/foo/bar/15?this=hello",
        url_for(set, { :controller => "foo", :action => "bar", :id => 15, :this => "hello" })
  end

  def test_extra_keys_not_first
    set.draw do
      match ':controller/:action/:id.:format'
      match ':controller/:action/:id'
    end
    extras = set.extra_keys(:controller => "foo", :action => "bar", :id => 15, :this => "hello", :that => "world")
    assert_equal %w(that this), extras.map { |e| e.to_s }.sort
  end

  def test_draw
    assert_equal 0, set.routes.size
    set.draw do
      match '/hello/world' => 'a#b'
    end
    assert_equal 1, set.routes.size
  end

  def test_draw_symbol_controller_name
    assert_equal 0, set.routes.size
    set.draw do
      match '/users/index' => 'users#index'
    end
    set.recognize_path('/users/index', :method => :get)
    assert_equal 1, set.routes.size
  end

  def test_named_draw
    assert_equal 0, set.routes.size
    set.draw do
      match '/hello/world' => 'a#b', :as => 'hello'
    end
    assert_equal 1, set.routes.size
    assert_equal set.routes.first, set.named_routes[:hello]
  end

  def test_later_named_routes_take_precedence
    set.draw do
      match '/hello/world' => 'a#b', :as => 'hello'
      match '/hello'       => 'a#b', :as => 'hello'
    end
    assert_equal set.routes.last, set.named_routes[:hello]
  end

  def setup_named_route_test
    set.draw do
      match '/people(/:id)' => 'people#show', :as => 'show'
      match '/people' => 'people#index', :as => 'index'
      match '/people/go/:foo/:bar/joe(/:id)' => 'people#multi', :as => 'multi'
      match '/admin/users' => 'admin/users#index', :as => "users"
    end

    MockController.build(set.url_helpers).new
  end

  def test_named_route_hash_access_method
    controller = setup_named_route_test

    assert_equal(
      { :controller => 'people', :action => 'show', :id => 5, :use_route => "show", :only_path => false },
      controller.send(:hash_for_show_url, :id => 5))

    assert_equal(
      { :controller => 'people', :action => 'index', :use_route => "index", :only_path => false },
      controller.send(:hash_for_index_url))

    assert_equal(
      { :controller => 'people', :action => 'show', :id => 5, :use_route => "show", :only_path => true },
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
    assert_equal '/admin/users', url_for(set, controller.send(:hash_for_users_url), { :controller => 'users', :action => 'index' })
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
    set.draw do
      match '/:controller/:action/:id'
    end

    assert_equal 1, set.routes.size

    assert_equal '/users/show/10',  url_for(set, { :controller => 'users', :action => 'show', :id => 10 })
    assert_equal '/users/index/10', url_for(set, { :controller => 'users', :id => 10 })

    assert_equal({:controller => 'users', :action => 'index', :id => '10'}, set.recognize_path('/users/index/10'))
    assert_equal({:controller => 'users', :action => 'index', :id => '10'}, set.recognize_path('/users/index/10/'))
  end

  def test_route_with_parameter_shell
    set.draw do
      match 'page/:id' => 'pages#show', :id => /\d+/
      match '/:controller(/:action(/:id))'
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
      set.draw do
        match 'page/:id' => 'pages#show', :id => /^\d+/
      end
    end
    assert_raise ArgumentError do
      set.draw do
        match 'page/:id' => 'pages#show', :id => /\A\d+/
      end
    end
    assert_raise ArgumentError do
      set.draw do
        match 'page/:id' => 'pages#show', :id => /\d+$/
      end
    end
    assert_raise ArgumentError do
      set.draw do
        match 'page/:id' => 'pages#show', :id => /\d+\Z/
      end
    end
    assert_raise ArgumentError do
      set.draw do
        match 'page/:id' => 'pages#show', :id => /\d+\z/
      end
    end
  end

  def test_route_constraints_with_options_method_condition_is_valid
    assert_nothing_raised do
      set.draw do
        match 'valid/route' => 'pages#show', :via => :options
      end
    end
  end

  def test_recognize_with_encoded_id_and_regex
    set.draw do
      match 'page/:id' => 'pages#show', :id => /[a-zA-Z0-9\+]+/
    end

    assert_equal({:controller => 'pages', :action => 'show', :id => '10'}, set.recognize_path('/page/10'))
    assert_equal({:controller => 'pages', :action => 'show', :id => 'hello+world'}, set.recognize_path('/page/hello+world'))
  end

  def test_recognize_with_http_methods
    set.draw do
      get    "/people"     => "people#index", :as => "people"
      post   "/people"     => "people#create"
      get    "/people/:id" => "people#show",  :as => "person"
      put    "/people/:id" => "people#update"
      delete "/people/:id" => "people#destroy"
    end

    params = set.recognize_path("/people", :method => :get)
    assert_equal("index", params[:action])

    params = set.recognize_path("/people", :method => :post)
    assert_equal("create", params[:action])

    params = set.recognize_path("/people/5", :method => :put)
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
    set.draw do
      match "/people" => 'people#index', :as => 'people', :via => :get
      root :to => "people#index"
    end

    params = set.recognize_path("/people", :method => :get)
    assert_equal("people", params[:controller])
    assert_equal("index", params[:action])

    params = set.recognize_path("/", :method => :get)
    assert_equal("people", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_typo_recognition
    set.draw do
      match 'articles/:year/:month/:day/:title' => 'articles#permalink',
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
    set.draw do
      match '/profile' => 'profile#index'
    end

    set.recognize_path("/profile") rescue nil

    assert !Object.const_defined?("Profiler__"), "Profiler should not be loaded"
  end

  def test_recognize_with_conditions_and_format
    set.draw do
      get "people/:id" => "people#show", :as => "person"
      put "people/:id" => "people#update"
      get "people/:id(.:format)" => "people#show"
    end

    params = set.recognize_path("/people/5", :method => :get)
    assert_equal("show", params[:action])
    assert_equal("5", params[:id])

    params = set.recognize_path("/people/5", :method => :put)
    assert_equal("update", params[:action])

    params = set.recognize_path("/people/5.png", :method => :get)
    assert_equal("show", params[:action])
    assert_equal("5", params[:id])
    assert_equal("png", params[:format])
  end

  def test_generate_with_default_action
    set.draw do
      match "/people", :controller => "people", :action => "index"
      match "/people/list", :controller => "people", :action => "list"
    end

    url = url_for(set, { :controller => "people", :action => "list" })
    assert_equal "/people/list", url
  end

  def test_root_map
    set.draw { root :to => 'people#index' }

    params = set.recognize_path("", :method => :get)
    assert_equal("people", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_namespace
    set.draw do

      namespace 'api' do
        match 'inventory' => 'products#inventory'
      end

    end

    params = set.recognize_path("/api/inventory", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("inventory", params[:action])
  end

  def test_namespaced_root_map
    set.draw do
      namespace 'api' do
        root :to => 'products#index'
      end
    end

    params = set.recognize_path("/api", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_namespace_with_path_prefix
    set.draw do
      scope :module => "api", :path => "prefix" do
        match 'inventory' => 'products#inventory'
      end
    end

    params = set.recognize_path("/prefix/inventory", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("inventory", params[:action])
  end

  def test_namespace_with_blank_path_prefix
    set.draw do
      scope :module => "api", :path => "" do
        match 'inventory' => 'products#inventory'
      end
    end

    params = set.recognize_path("/inventory", :method => :get)
    assert_equal("api/products", params[:controller])
    assert_equal("inventory", params[:action])
  end

  def test_generate_changes_controller_module
    set.draw { match ':controller/:action/:id' }
    current = { :controller => "bling/bloop", :action => "bap", :id => 9 }

    assert_equal "/foo/bar/baz/7",
        url_for(set, { :controller => "foo/bar", :action => "baz", :id => 7 }, current)
  end

  def test_id_is_sticky_when_it_ought_to_be
    set.draw do
      match ':controller/:id/:action'
    end

    url = url_for(set, { :action => "destroy" }, { :controller => "people", :action => "show", :id => "7" })
    assert_equal "/people/7/destroy", url
  end

  def test_use_static_path_when_possible
    set.draw do
      match 'about' => "welcome#about"
      match ':controller/:action/:id'
    end

    url = url_for(set, { :controller => "welcome", :action => "about" },
      { :controller => "welcome", :action => "get", :id => "7" })

    assert_equal "/about", url
  end

  def test_generate
    set.draw { match ':controller/:action/:id' }

    args = { :controller => "foo", :action => "bar", :id => "7", :x => "y" }
    assert_equal "/foo/bar/7?x=y",     url_for(set, args)
    assert_equal ["/foo/bar/7", [:x]], set.generate_extras(args)
    assert_equal [:x], set.extra_keys(args)
  end

  def test_generate_with_path_prefix
    set.draw do
      scope "my" do
        match ':controller(/:action(/:id))'
      end
    end

    args = { :controller => "foo", :action => "bar", :id => "7", :x => "y" }
    assert_equal "/my/foo/bar/7?x=y", url_for(set, args)
  end

  def test_generate_with_blank_path_prefix
    set.draw do
      scope "" do
        match ':controller(/:action(/:id))'
      end
    end

    args = { :controller => "foo", :action => "bar", :id => "7", :x => "y" }
    assert_equal "/foo/bar/7?x=y", url_for(set, args)
  end

  def test_named_routes_are_never_relative_to_modules
    set.draw do
      match "/connection/manage(/:action)" => 'connection/manage#index'
      match "/connection/connection" => "connection/connection#index"
      match '/connection' => 'connection#index', :as => 'family_connection'
    end

    url = url_for(set, { :controller => "connection" }, { :controller => 'connection/manage' })
    assert_equal "/connection/connection", url

    url = url_for(set, { :use_route => :family_connection, :controller => "connection" }, { :controller => 'connection/manage' })
    assert_equal "/connection", url
  end

  def test_action_left_off_when_id_is_recalled
    set.draw do
      match ':controller(/:action(/:id))'
    end
    assert_equal '/books', url_for(set,
      {:controller => 'books', :action => 'index'},
      {:controller => 'books', :action => 'show', :id => '10'}
    )
  end

  def test_query_params_will_be_shown_when_recalled
    set.draw do
      match 'show_weblog/:parameter' => 'weblog#show'
      match ':controller(/:action(/:id))'
    end
    assert_equal '/weblog/edit?parameter=1', url_for(set,
      {:action => 'edit', :parameter => 1},
      {:controller => 'weblog', :action => 'show', :parameter => 1}
    )
  end

  def test_format_is_not_inherit
    set.draw do
      match '/posts(.:format)' => 'posts#index'
    end

    assert_equal '/posts', url_for(set,
      {:controller => 'posts'},
      {:controller => 'posts', :action => 'index', :format => 'xml'}
    )

    assert_equal '/posts.xml', url_for(set,
      {:controller => 'posts', :format => 'xml'},
      {:controller => 'posts', :action => 'index', :format => 'xml'}
    )
  end

  def test_expiry_determination_should_consider_values_with_to_param
    set.draw { match 'projects/:project_id/:controller/:action' }
    assert_equal '/projects/1/weblog/show', url_for(set,
      { :action => 'show', :project_id => 1 },
      { :controller => 'weblog', :action => 'show', :project_id => '1' })
  end

  def test_named_route_in_nested_resource
    set.draw do
      resources :projects do
        member do
          match 'milestones' => 'milestones#index', :as => 'milestones'
        end
      end
    end

    params = set.recognize_path("/projects/1/milestones", :method => :get)
    assert_equal("milestones", params[:controller])
    assert_equal("index", params[:action])
  end

  def test_setting_root_in_namespace_using_symbol
    assert_nothing_raised do
      set.draw do
        namespace :admin do
          root :to => "home#index"
        end
      end
    end
  end

  def test_setting_root_in_namespace_using_string
    assert_nothing_raised do
      set.draw do
        namespace 'admin' do
          root :to => "home#index"
        end
      end
    end
  end

  def test_route_constraints_with_unsupported_regexp_options_must_error
    assert_raise ArgumentError do
      set.draw do
        match 'page/:name' => 'pages#show',
          :constraints => { :name => /(david|jamis)/m }
      end
    end
  end

  def test_route_constraints_with_supported_options_must_not_error
    assert_nothing_raised do
      set.draw do
        match 'page/:name' => 'pages#show',
          :constraints => { :name => /(david|jamis)/i }
      end
    end
    assert_nothing_raised do
      set.draw do
        match 'page/:name' => 'pages#show',
          :constraints => { :name => / # Desperately overcommented regexp
                                      ( #Either
                                       david #The Creator
                                      | #Or
                                        jamis #The Deployer
                                      )/x }
      end
    end
  end

  def test_route_requirement_recognize_with_ignore_case
    set.draw do
      match 'page/:name' => 'pages#show',
        :constraints => {:name => /(david|jamis)/i}
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => 'jamis'}, set.recognize_path('/page/jamis'))
    assert_raise ActionController::RoutingError do
      set.recognize_path('/page/davidjamis')
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => 'DAVID'}, set.recognize_path('/page/DAVID'))
  end

  def test_route_requirement_generate_with_ignore_case
    set.draw do
      match 'page/:name' => 'pages#show',
        :constraints => {:name => /(david|jamis)/i}
    end

    url = url_for(set, { :controller => 'pages', :action => 'show', :name => 'david' })
    assert_equal "/page/david", url
    assert_raise ActionController::RoutingError do
      url_for(set, { :controller => 'pages', :action => 'show', :name => 'davidjamis' })
    end
    url = url_for(set, { :controller => 'pages', :action => 'show', :name => 'JAMIS' })
    assert_equal "/page/JAMIS", url
  end

  def test_route_requirement_recognize_with_extended_syntax
    set.draw do
      match 'page/:name' => 'pages#show',
        :constraints => {:name => / # Desperately overcommented regexp
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

  def test_route_requirement_with_xi_modifiers
    set.draw do
      match 'page/:name' => 'pages#show',
        :constraints => {:name => / # Desperately overcommented regexp
                                    ( #Either
                                     david #The Creator
                                    | #Or
                                      jamis #The Deployer
                                    )/xi}
    end

    assert_equal({:controller => 'pages', :action => 'show', :name => 'JAMIS'},
        set.recognize_path('/page/JAMIS'))

    assert_equal "/page/JAMIS",
        url_for(set, { :controller => 'pages', :action => 'show', :name => 'JAMIS' })
  end

  def test_routes_with_symbols
    set.draw do
      match 'unnamed', :controller => :pages, :action => :show, :name => :as_symbol
      match 'named'  , :controller => :pages, :action => :show, :name => :as_symbol, :as => :named
    end
    assert_equal({:controller => 'pages', :action => 'show', :name => :as_symbol}, set.recognize_path('/unnamed'))
    assert_equal({:controller => 'pages', :action => 'show', :name => :as_symbol}, set.recognize_path('/named'))
  end

  def test_regexp_chunk_should_add_question_mark_for_optionals
    set.draw do
      match '/' => 'foo#index'
      match '/hello' => 'bar#index'
    end

    assert_equal '/',      url_for(set, { :controller => 'foo' })
    assert_equal '/hello', url_for(set, { :controller => 'bar' })

    assert_equal({:controller => "foo", :action => "index"}, set.recognize_path('/'))
    assert_equal({:controller => "bar", :action => "index"}, set.recognize_path('/hello'))
  end

  def test_assign_route_options_with_anchor_chars
    set.draw do
      match '/cars/:action/:person/:car/', :controller => 'cars'
    end

    assert_equal '/cars/buy/1/2', url_for(set, { :controller => 'cars', :action => 'buy', :person => '1', :car => '2' })

    assert_equal({:controller => "cars", :action => "buy", :person => "1", :car => "2"}, set.recognize_path('/cars/buy/1/2'))
  end

  def test_segmentation_of_dot_path
    set.draw do
      match '/books/:action.rss', :controller => 'books'
    end

    assert_equal '/books/list.rss', url_for(set, { :controller => 'books', :action => 'list' })

    assert_equal({:controller => "books", :action => "list"}, set.recognize_path('/books/list.rss'))
  end

  def test_segmentation_of_dynamic_dot_path
    set.draw do
      match '/books(/:action(.:format))', :controller => 'books'
    end

    assert_equal '/books/list.rss', url_for(set, { :controller => 'books', :action => 'list', :format => 'rss' })
    assert_equal '/books/list.xml', url_for(set, { :controller => 'books', :action => 'list', :format => 'xml' })
    assert_equal '/books/list',     url_for(set, { :controller => 'books', :action => 'list' })
    assert_equal '/books',          url_for(set, { :controller => 'books', :action => 'index' })

    assert_equal({:controller => "books", :action => "list", :format => "rss"}, set.recognize_path('/books/list.rss'))
    assert_equal({:controller => "books", :action => "list", :format => "xml"}, set.recognize_path('/books/list.xml'))
    assert_equal({:controller => "books", :action => "list"},  set.recognize_path('/books/list'))
    assert_equal({:controller => "books", :action => "index"}, set.recognize_path('/books'))
  end

  def test_slashes_are_implied
    @set = nil
    set.draw { match("/:controller(/:action(/:id))") }

    assert_equal '/content',        url_for(set, { :controller => 'content', :action => 'index' })
    assert_equal '/content/list',   url_for(set, { :controller => 'content', :action => 'list' })
    assert_equal '/content/show/1', url_for(set, { :controller => 'content', :action => 'show', :id => '1' })

    assert_equal({:controller => "content", :action => "index"}, set.recognize_path('/content'))
    assert_equal({:controller => "content", :action => "index"}, set.recognize_path('/content/index'))
    assert_equal({:controller => "content", :action => "list"},  set.recognize_path('/content/list'))
    assert_equal({:controller => "content", :action => "show", :id => "1"}, set.recognize_path('/content/show/1'))
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
    assert_equal '/accounts', url_for(default_route_set, { :controller => 'accounts', :action => 'index' })
  end

  def test_default_route_should_include_default_action_when_id_present
    assert_equal '/accounts/index/20', url_for(default_route_set, { :controller => 'accounts', :action => 'index', :id => '20' })
  end

  def test_default_route_should_work_with_action_but_no_id
    assert_equal '/accounts/list_all', url_for(default_route_set, { :controller => 'accounts', :action => 'list_all' })
  end

  def test_default_route_should_uri_escape_pluses
    expected = { :controller => 'pages', :action => 'show', :id => 'hello world' }
    assert_equal expected, default_route_set.recognize_path('/pages/show/hello%20world')
    assert_equal '/pages/show/hello%20world', url_for(default_route_set, expected)

    expected[:id] = 'hello+world'
    assert_equal expected, default_route_set.recognize_path('/pages/show/hello+world')
    assert_equal expected, default_route_set.recognize_path('/pages/show/hello%2Bworld')
    assert_equal '/pages/show/hello+world', url_for(default_route_set, expected)
  end

  def test_build_empty_query_string
    assert_uri_equal '/foo', url_for(default_route_set, { :controller => 'foo' })
  end

  def test_build_query_string_with_nil_value
    assert_uri_equal '/foo', url_for(default_route_set, { :controller => 'foo', :x => nil })
  end

  def test_simple_build_query_string
    assert_uri_equal '/foo?x=1&y=2', url_for(default_route_set, { :controller => 'foo', :x => '1', :y => '2' })
  end

  def test_convert_ints_build_query_string
    assert_uri_equal '/foo?x=1&y=2', url_for(default_route_set, { :controller => 'foo', :x => 1, :y => 2 })
  end

  def test_escape_spaces_build_query_string
    assert_uri_equal '/foo?x=hello+world&y=goodbye+world', url_for(default_route_set, { :controller => 'foo', :x => 'hello world', :y => 'goodbye world' })
  end

  def test_expand_array_build_query_string
    assert_uri_equal '/foo?x%5B%5D=1&x%5B%5D=2', url_for(default_route_set, { :controller => 'foo', :x => [1, 2] })
  end

  def test_escape_spaces_build_query_string_selected_keys
    assert_uri_equal '/foo?x=hello+world', url_for(default_route_set, { :controller => 'foo', :x => 'hello world' })
  end

  def test_generate_with_default_params
    set.draw do
      match 'dummy/page/:page' => 'dummy#show'
      match 'dummy/dots/page.:page' => 'dummy#dots'
      match 'ibocorp(/:page)' => 'ibocorp#show',
                             :constraints => { :page => /\d+/ },
                             :defaults => { :page => 1 }

      match ':controller/:action/:id'
    end

    assert_equal '/ibocorp', url_for(set, { :controller => 'ibocorp', :action => "show", :page => 1 })
  end

  def test_generate_with_optional_params_recalls_last_request
    set.draw do
      match "blog/", :controller => "blog", :action => "index"

      match "blog(/:year(/:month(/:day)))",
            :controller => "blog",
            :action => "show_date",
            :constraints => { :year => /(19|20)\d\d/, :month => /[01]?\d/, :day => /[0-3]?\d/ },
            :day => nil, :month => nil

      match "blog/show/:id", :controller => "blog", :action => "show", :id => /\d+/
      match "blog/:controller/:action(/:id)"
      match "*anything", :controller => "blog", :action => "unknown_request"
    end

    assert_equal({:controller => "blog", :action => "index"}, set.recognize_path("/blog"))
    assert_equal({:controller => "blog", :action => "show", :id => "123"}, set.recognize_path("/blog/show/123"))
    assert_equal({:controller => "blog", :action => "show_date", :year => "2004", :day => nil, :month => nil }, set.recognize_path("/blog/2004"))
    assert_equal({:controller => "blog", :action => "show_date", :year => "2004", :month => "12", :day => nil }, set.recognize_path("/blog/2004/12"))
    assert_equal({:controller => "blog", :action => "show_date", :year => "2004", :month => "12", :day => "25"}, set.recognize_path("/blog/2004/12/25"))
    assert_equal({:controller => "articles", :action => "edit", :id => "123"}, set.recognize_path("/blog/articles/edit/123"))
    assert_equal({:controller => "articles", :action => "show_stats"}, set.recognize_path("/blog/articles/show_stats"))
    assert_equal({:controller => "blog", :action => "unknown_request", :anything => "blog/wibble"}, set.recognize_path("/blog/wibble"))
    assert_equal({:controller => "blog", :action => "unknown_request", :anything => "junk"}, set.recognize_path("/junk"))

    last_request = set.recognize_path("/blog/2006/07/28").freeze
    assert_equal({:controller => "blog",  :action => "show_date", :year => "2006", :month => "07", :day => "28"}, last_request)
    assert_equal("/blog/2006/07/25", url_for(set, { :day => 25 }, last_request))
    assert_equal("/blog/2005",       url_for(set, { :year => 2005 }, last_request))
    assert_equal("/blog/show/123",   url_for(set, { :action => "show" , :id => 123 }, last_request))
    assert_equal("/blog/2006",       url_for(set, { :year => 2006 }, last_request))
    assert_equal("/blog/2006",       url_for(set, { :year => 2006, :month => nil }, last_request))
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
  include RoutingTestHelpers

  Model = Struct.new(:to_param)

  Mapping = lambda {
    namespace :admin do
      resources :users, :posts
    end

    namespace 'api' do
      root :to => 'users#index'
    end

    match '/blog(/:year(/:month(/:day)))' => 'posts#show_date',
      :constraints => {
        :year => /(19|20)\d\d/,
        :month => /[01]?\d/,
        :day => /[0-3]?\d/
      },
      :day => nil,
      :month => nil

    match 'archive/:year', :controller => 'archive', :action => 'index',
      :defaults => { :year => nil },
      :constraints => { :year => /\d{4}/ },
      :as => "blog"

    resources :people
    match 'legacy/people' => "people#index", :legacy => "true"

    match 'symbols', :controller => :symbols, :action => :show, :name => :as_symbol
    match 'id_default(/:id)' => "foo#id_default", :id => 1
    match 'get_or_post' => "foo#get_or_post", :via => [:get, :post]
    match 'optional/:optional' => "posts#index"
    match 'projects/:project_id' => "project#index", :as => "project"
    match 'clients' => "projects#index"

    match 'ignorecase/geocode/:postalcode' => 'geocode#show', :postalcode => /hx\d\d-\d[a-z]{2}/i
    match 'extended/geocode/:postalcode' => 'geocode#show',:constraints => {
                  :postalcode => /# Postcode format
                                  \d{5} #Prefix
                                  (-\d{4})? #Suffix
                                  /x
                  }, :as => "geocode"

    match 'news(.:format)' => "news#index"

    match 'comment/:id(/:action)' => "comments#show"
    match 'ws/:controller(/:action(/:id))', :ws => true
    match 'account(/:action)' => "account#subscription"
    match 'pages/:page_id/:controller(/:action(/:id))'
    match ':controller/ping', :action => 'ping'
    match ':controller(/:action(/:id))(.:format)'
    root :to => "news#index"
  }

  def setup
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw(&Mapping)
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

    assert_equal({:controller => 'posts', :action => 'show_date', :year => '2009', :month => nil, :day => nil }, @routes.recognize_path('/blog/2009', :method => :get))
    assert_equal({:controller => 'posts', :action => 'show_date', :year => '2009', :month => '01', :day => nil }, @routes.recognize_path('/blog/2009/01', :method => :get))
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
    assert_equal({:controller => 'foo', :action => 'id_default', :id => 1 }, @routes.recognize_path('/id_default'))
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

    assert_equal({:controller => 'news', :action => 'index' }, @routes.recognize_path('/', :method => :get))
    assert_equal({:controller => 'news', :action => 'index', :format => 'rss'}, @routes.recognize_path('/news.rss', :method => :get))

    assert_raise(ActionController::RoutingError) { @routes.recognize_path('/none', :method => :get) }
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
