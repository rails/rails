# encoding: UTF-8
require 'abstract_unit'

module ActionDispatch
  module Journey
    class TestRouter < ActiveSupport::TestCase
      attr_reader :routes

      def setup
        @app       = Routing::RouteSet::Dispatcher.new({})
        @routes    = Routes.new
        @router    = Router.new(@routes)
        @formatter = Formatter.new(@routes)
      end

      class FakeRequestFeeler < Struct.new(:env, :called)
        def new env
          self.env = env
          self
        end

        def hello
          self.called = true
          'world'
        end

        def path_info; env['PATH_INFO']; end
        def request_method; env['REQUEST_METHOD']; end
        def ip; env['REMOTE_ADDR']; end
      end

      def test_dashes
        router = Router.new(routes)

        exp = Router::Strexp.build '/foo-bar-baz', {}, ['/.?']
        path  = Path::Pattern.new exp

        routes.add_route nil, path, {}, {:id => nil}, {}

        env = rails_env 'PATH_INFO' => '/foo-bar-baz'
        called = false
        router.recognize(env) do |r, params|
          called = true
        end
        assert called
      end

      def test_unicode
        router = Router.new(routes)

        #match the escaped version of /ほげ
        exp = Router::Strexp.build '/%E3%81%BB%E3%81%92', {}, ['/.?']
        path  = Path::Pattern.new exp

        routes.add_route nil, path, {}, {:id => nil}, {}

        env = rails_env 'PATH_INFO' => '/%E3%81%BB%E3%81%92'
        called = false
        router.recognize(env) do |r, params|
          called = true
        end
        assert called
      end

      def test_request_class_and_requirements_success
        klass  = FakeRequestFeeler.new nil
        router = Router.new(routes)

        requirements = { :hello => /world/ }

        exp = Router::Strexp.build '/foo(/:id)', {}, ['/.?']
        path  = Path::Pattern.new exp

        routes.add_route nil, path, requirements, {:id => nil}, {}

        env = rails_env({'PATH_INFO' => '/foo/10'}, klass)
        router.recognize(env) do |r, params|
          assert_equal({:id => '10'}, params)
        end

        assert klass.called, 'hello should have been called'
        assert_equal env.env, klass.env
      end

      def test_request_class_and_requirements_fail
        klass  = FakeRequestFeeler.new nil
        router = Router.new(routes)

        requirements = { :hello => /mom/ }

        exp = Router::Strexp.build '/foo(/:id)', {}, ['/.?']
        path  = Path::Pattern.new exp

        router.routes.add_route nil, path, requirements, {:id => nil}, {}

        env = rails_env({'PATH_INFO' => '/foo/10'}, klass)
        router.recognize(env) do |r, params|
          flunk 'route should not be found'
        end

        assert klass.called, 'hello should have been called'
        assert_equal env.env, klass.env
      end

      class CustomPathRequest < ActionDispatch::Request
        def path_info
          env['custom.path_info']
        end

        def path_info=(x)
          env['custom.path_info'] = x
        end
      end

      def test_request_class_overrides_path_info
        router = Router.new(routes)

        exp = Router::Strexp.build '/bar', {}, ['/.?']
        path = Path::Pattern.new exp

        routes.add_route nil, path, {}, {}, {}

        env = rails_env({'PATH_INFO' => '/foo',
                         'custom.path_info' => '/bar'}, CustomPathRequest)

        recognized = false
        router.recognize(env) do |r, params|
          recognized = true
        end

        assert recognized, "route should have been recognized"
      end

      def test_regexp_first_precedence
        add_routes @router, [
          Router::Strexp.build("/whois/:domain", {:domain => /\w+\.[\w\.]+/}, ['/', '.', '?']),
          Router::Strexp.build("/whois/:id(.:format)", {}, ['/', '.', '?'])
        ]

        env = rails_env 'PATH_INFO' => '/whois/example.com'

        list = []
        @router.recognize(env) do |r, params|
          list << r
        end
        assert_equal 2, list.length

        r = list.first

        assert_equal '/whois/:domain', r.path.spec.to_s
      end

      def test_required_parts_verified_are_anchored
        add_routes @router, [
          Router::Strexp.build("/foo/:id", { :id => /\d/ }, ['/', '.', '?'], false)
        ]

        assert_raises(ActionController::UrlGenerationError) do
          @formatter.generate(nil, { :id => '10' }, { })
        end
      end

      def test_required_parts_are_verified_when_building
        add_routes @router, [
          Router::Strexp.build("/foo/:id", { :id => /\d+/ }, ['/', '.', '?'], false)
        ]

        path, _ = @formatter.generate(nil, { :id => '10' }, { })
        assert_equal '/foo/10', path

        assert_raises(ActionController::UrlGenerationError) do
          @formatter.generate(nil, { :id => 'aa' }, { })
        end
      end

      def test_only_required_parts_are_verified
        add_routes @router, [
          Router::Strexp.build("/foo(/:id)", {:id => /\d/}, ['/', '.', '?'], false)
        ]

        path, _ = @formatter.generate(nil, { :id => '10' }, { })
        assert_equal '/foo/10', path

        path, _ = @formatter.generate(nil, { }, { })
        assert_equal '/foo', path

        path, _ = @formatter.generate(nil, { :id => 'aa' }, { })
        assert_equal '/foo/aa', path
      end

      def test_knows_what_parts_are_missing_from_named_route
        route_name = "gorby_thunderhorse"
        pattern = Router::Strexp.build("/foo/:id", { :id => /\d+/ }, ['/', '.', '?'], false)
        path = Path::Pattern.new pattern
        @router.routes.add_route nil, path, {}, {}, route_name

        error = assert_raises(ActionController::UrlGenerationError) do
          @formatter.generate(route_name, { }, { })
        end

        assert_match(/missing required keys: \[:id\]/, error.message)
      end

      def test_does_not_include_missing_keys_message
        route_name = "gorby_thunderhorse"

        error = assert_raises(ActionController::UrlGenerationError) do
          @formatter.generate(route_name, { }, { })
        end

        assert_no_match(/missing required keys: \[\]/, error.message)
      end

      def test_X_Cascade
        add_routes @router, [ "/messages(.:format)" ]
        resp = @router.serve(rails_env({ 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/lol' }))
        assert_equal ['Not Found'], resp.last
        assert_equal 'pass', resp[1]['X-Cascade']
        assert_equal 404, resp.first
      end

      def test_clear_trailing_slash_from_script_name_on_root_unanchored_routes
        route_set = Routing::RouteSet.new
        mapper = Routing::Mapper.new route_set

        app    = lambda { |env| [200, {}, ['success!']] }
        mapper.get '/weblog', :to => app

        env  = rack_env('SCRIPT_NAME' => '', 'PATH_INFO' => '/weblog')
        resp = route_set.call env
        assert_equal ['success!'], resp.last
        assert_equal '', env['SCRIPT_NAME']
      end

      def test_defaults_merge_correctly
        path  = Path::Pattern.from_string '/foo(/:id)'
        @router.routes.add_route nil, path, {}, {:id => nil}, {}

        env = rails_env 'PATH_INFO' => '/foo/10'
        @router.recognize(env) do |r, params|
          assert_equal({:id => '10'}, params)
        end

        env = rails_env 'PATH_INFO' => '/foo'
        @router.recognize(env) do |r, params|
          assert_equal({:id => nil}, params)
        end
      end

      def test_recognize_with_unbound_regexp
        add_routes @router, [
          Router::Strexp.build("/foo", { }, ['/', '.', '?'], false)
        ]

        env = rails_env 'PATH_INFO' => '/foo/bar'

        @router.recognize(env) { |*_| }

        assert_equal '/foo', env.env['SCRIPT_NAME']
        assert_equal '/bar', env.env['PATH_INFO']
      end

      def test_bound_regexp_keeps_path_info
        add_routes @router, [
          Router::Strexp.build("/foo", { }, ['/', '.', '?'], true)
        ]

        env = rails_env 'PATH_INFO' => '/foo'

        before = env.env['SCRIPT_NAME']

        @router.recognize(env) { |*_| }

        assert_equal before, env.env['SCRIPT_NAME']
        assert_equal '/foo', env.env['PATH_INFO']
      end

      def test_path_not_found
        add_routes @router, [
          "/messages(.:format)",
          "/messages/new(.:format)",
          "/messages/:id/edit(.:format)",
          "/messages/:id(.:format)"
        ]
        env = rails_env 'PATH_INFO' => '/messages/unknown/path'
        yielded = false

        @router.recognize(env) do |*whatever|
          yielded = true
        end
        assert_not yielded
      end

      def test_required_part_in_recall
        add_routes @router, [ "/messages/:a/:b" ]

        path, _ = @formatter.generate(nil, { :a => 'a' }, { :b => 'b' })
        assert_equal "/messages/a/b", path
      end

      def test_splat_in_recall
        add_routes @router, [ "/*path" ]

        path, _ = @formatter.generate(nil, { }, { :path => 'b' })
        assert_equal "/b", path
      end

      def test_recall_should_be_used_when_scoring
        add_routes @router, [
          "/messages/:action(/:id(.:format))",
          "/messages/:id(.:format)"
        ]

        path, _ = @formatter.generate(nil, { :id => 10 }, { :action => 'index' })
        assert_equal "/messages/index/10", path
      end

      def test_nil_path_parts_are_ignored
        path  = Path::Pattern.from_string "/:controller(/:action(.:format))"
        @router.routes.add_route @app, path, {}, {}, {}

        params = { :controller => "tasks", :format => nil }
        extras = { :action => 'lol' }

        path, _ = @formatter.generate(nil, params, extras)
        assert_equal '/tasks', path
      end

      def test_generate_slash
        params = [ [:controller, "tasks"],
                   [:action, "show"] ]
        str = Router::Strexp.build("/", Hash[params], ['/', '.', '?'], true)
        path  = Path::Pattern.new str

        @router.routes.add_route @app, path, {}, {}, {}

        path, _ = @formatter.generate(nil, Hash[params], {})
        assert_equal '/', path
      end

      def test_generate_calls_param_proc
        path  = Path::Pattern.from_string '/:controller(/:action)'
        @router.routes.add_route @app, path, {}, {}, {}

        parameterized = []
        params = [ [:controller, "tasks"],
                   [:action, "show"] ]

        @formatter.generate(
          nil,
          Hash[params],
          {},
          lambda { |k,v| parameterized << [k,v]; v })

        assert_equal params.map(&:to_s).sort, parameterized.map(&:to_s).sort
      end

      def test_generate_id
        path  = Path::Pattern.from_string '/:controller(/:action)'
        @router.routes.add_route @app, path, {}, {}, {}

        path, params = @formatter.generate(
          nil, {:id=>1, :controller=>"tasks", :action=>"show"}, {})
        assert_equal '/tasks/show', path
        assert_equal({:id => 1}, params)
      end

      def test_generate_escapes
        path  = Path::Pattern.from_string '/:controller(/:action)'
        @router.routes.add_route @app, path, {}, {}, {}

        path, _ = @formatter.generate(nil,
          { :controller        => "tasks",
                 :action            => "a/b c+d",
        }, {})
        assert_equal '/tasks/a%2Fb%20c+d', path
      end

      def test_generate_escapes_with_namespaced_controller
        path  = Path::Pattern.from_string '/:controller(/:action)'
        @router.routes.add_route @app, path, {}, {}, {}

        path, _ = @formatter.generate(
          nil, { :controller        => "admin/tasks",
                 :action            => "a/b c+d",
        }, {})
        assert_equal '/admin/tasks/a%2Fb%20c+d', path
      end

      def test_generate_extra_params
        path  = Path::Pattern.from_string '/:controller(/:action)'
        @router.routes.add_route @app, path, {}, {}, {}

        path, params = @formatter.generate(
          nil, { :id                => 1,
                 :controller        => "tasks",
                 :action            => "show",
                 :relative_url_root => nil
        }, {})
        assert_equal '/tasks/show', path
        assert_equal({:id => 1, :relative_url_root => nil}, params)
      end

      def test_generate_uses_recall_if_needed
        path  = Path::Pattern.from_string '/:controller(/:action(/:id))'
        @router.routes.add_route @app, path, {}, {}, {}

        path, params = @formatter.generate(
          nil,
          {:controller =>"tasks", :id => 10},
          {:action     =>"index"})
        assert_equal '/tasks/index/10', path
        assert_equal({}, params)
      end

      def test_generate_with_name
        path  = Path::Pattern.from_string '/:controller(/:action)'
        @router.routes.add_route @app, path, {}, {}, "tasks"

        path, params = @formatter.generate(
          "tasks",
          {:controller=>"tasks"},
          {:controller=>"tasks", :action=>"index"})
        assert_equal '/tasks', path
        assert_equal({}, params)
      end

      {
        '/content'          => { :controller => 'content' },
        '/content/list'     => { :controller => 'content', :action => 'list' },
        '/content/show/10'  => { :controller => 'content', :action => 'show', :id => "10" },
      }.each do |request_path, expected|
        define_method("test_recognize_#{expected.keys.map(&:to_s).join('_')}") do
          path  = Path::Pattern.from_string "/:controller(/:action(/:id))"
          app   = Object.new
          route = @router.routes.add_route(app, path, {}, {}, {})

          env = rails_env 'PATH_INFO' => request_path
          called   = false

          @router.recognize(env) do |r, params|
            assert_equal route, r
            assert_equal(expected, params)
            called = true
          end

          assert called
        end
      end

      {
        :segment => ['/a%2Fb%20c+d/splat', { :segment => 'a/b c+d', :splat => 'splat'   }],
        :splat   => ['/segment/a/b%20c+d', { :segment => 'segment', :splat => 'a/b c+d' }]
      }.each do |name, (request_path, expected)|
        define_method("test_recognize_#{name}") do
          path  = Path::Pattern.from_string '/:segment/*splat'
          app   = Object.new
          route = @router.routes.add_route(app, path, {}, {}, {})

          env = rails_env 'PATH_INFO' => request_path
          called   = false

          @router.recognize(env) do |r, params|
            assert_equal route, r
            assert_equal(expected, params)
            called = true
          end

          assert called
        end
      end

      def test_namespaced_controller
        strexp = Router::Strexp.build(
          "/:controller(/:action(/:id))",
          { :controller => /.+?/ },
          ["/", ".", "?"]
        )
        path  = Path::Pattern.new strexp
        app   = Object.new
        route = @router.routes.add_route(app, path, {}, {}, {})

        env = rails_env 'PATH_INFO' => '/admin/users/show/10'
        called   = false
        expected = {
          :controller => 'admin/users',
          :action     => 'show',
          :id         => '10'
        }

        @router.recognize(env) do |r, params|
          assert_equal route, r
          assert_equal(expected, params)
          called = true
        end
        assert called
      end

      def test_recognize_literal
        path   = Path::Pattern.from_string "/books(/:action(.:format))"
        app    = Object.new
        route  = @router.routes.add_route(app, path, {}, {:controller => 'books'})

        env    = rails_env 'PATH_INFO' => '/books/list.rss'
        expected = { :controller => 'books', :action => 'list', :format => 'rss' }
        called = false
        @router.recognize(env) do |r, params|
          assert_equal route, r
          assert_equal(expected, params)
          called = true
        end

        assert called
      end

      def test_recognize_head_route
        path   = Path::Pattern.from_string "/books(/:action(.:format))"
        app    = Object.new
        conditions = { request_method: 'HEAD' }
        @router.routes.add_route(app, path, conditions, {})

        env = rails_env(
          'PATH_INFO' => '/books/list.rss',
          'REQUEST_METHOD' => 'HEAD'
        )

        called = false
        @router.recognize(env) do |r, params|
          called = true
        end

        assert called
      end

      def test_recognize_head_request_as_get_route
        path   = Path::Pattern.from_string "/books(/:action(.:format))"
        app    = Object.new
        conditions = {
          :request_method => 'GET'
        }
        @router.routes.add_route(app, path, conditions, {})

        env = rails_env 'PATH_INFO' => '/books/list.rss',
                        "REQUEST_METHOD"    => "HEAD"

        called = false
        @router.recognize(env) do |r, params|
          called = true
        end

        assert called
      end

      def test_recognize_cares_about_verbs
        path   = Path::Pattern.from_string "/books(/:action(.:format))"
        app    = Object.new
        conditions = { request_method: 'GET' }
        @router.routes.add_route(app, path, conditions, {})

        env = rails_env 'PATH_INFO' => '/books/list.rss',
                        "REQUEST_METHOD" => "POST"

        called = false
        @router.recognize(env) do |r, params|
          called = true
        end

        assert_not called

        conditions = conditions.dup
        conditions[:request_method] = 'POST'

        post = @router.routes.add_route(app, path, conditions, {})

        called = false
        @router.recognize(env) do |r, params|
          assert_equal post, r
          called = true
        end

        assert called
      end

      private

      def add_routes router, paths
        paths.each do |path|
          if String === path
            path  = Path::Pattern.from_string path
          else
            path  = Path::Pattern.new path
          end
          router.routes.add_route @app, path, {}, {}, {}
        end
      end

      def rails_env env, klass = ActionDispatch::Request
        klass.new(rack_env(env))
      end

      def rack_env env
        {
          "rack.version"      => [1, 1],
          "rack.input"        => StringIO.new,
          "rack.errors"       => StringIO.new,
          "rack.multithread"  => true,
          "rack.multiprocess" => true,
          "rack.run_once"     => false,
          "REQUEST_METHOD"    => "GET",
          "SERVER_NAME"       => "example.org",
          "SERVER_PORT"       => "80",
          "QUERY_STRING"      => "",
          "PATH_INFO"         => "/content",
          "rack.url_scheme"   => "http",
          "HTTPS"             => "off",
          "SCRIPT_NAME"       => "",
          "CONTENT_LENGTH"    => "0"
        }.merge env
      end
    end
  end
end
