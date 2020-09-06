# frozen_string_literal: true

require 'abstract_unit'
require 'rack/utils'

module ActionDispatch
  module Journey
    class TestRouter < ActiveSupport::TestCase
      attr_reader :mapper, :routes, :route_set, :router

      def setup
        @app = Routing::RouteSet::Dispatcher.new({})
        @route_set = ActionDispatch::Routing::RouteSet.new
        @routes = @route_set.router.routes
        @router = @route_set.router
        @formatter = @route_set.formatter
        @mapper = ActionDispatch::Routing::Mapper.new @route_set
      end

      def test_dashes
        get '/foo-bar-baz', to: 'foo#bar'

        env = rails_env 'PATH_INFO' => '/foo-bar-baz'
        called = false
        router.recognize(env) do |r, params|
          called = true
        end
        assert called
      end

      def test_unicode
        get '/ほげ', to: 'foo#bar'

        # match the escaped version of /ほげ
        env = rails_env 'PATH_INFO' => '/%E3%81%BB%E3%81%92'
        called = false
        router.recognize(env) do |r, params|
          called = true
        end
        assert called
      end

      def test_regexp_first_precedence
        get '/whois/:domain', domain: /\w+\.[\w\.]+/, to: 'foo#bar'
        get '/whois/:id(.:format)', to: 'foo#baz'

        env = rails_env 'PATH_INFO' => '/whois/example.com'

        list = []
        router.recognize(env) do |r, params|
          list << r
        end
        assert_equal 2, list.length

        r = list.first

        assert_equal '/whois/:domain(.:format)', r.path.spec.to_s
      end

      def test_required_parts_verified_are_anchored
        get '/foo/:id', id: /\d/, anchor: false, to: 'foo#bar'

        assert_raises(ActionController::UrlGenerationError) do
          @route_set.url_for({ controller: 'foo', action: 'bar', id: '10' }, nil)
        end
      end

      def test_required_parts_are_verified_when_building
        get '/foo/:id', id: /\d+/, anchor: false, to: 'foo#bar'

        path, _ = _generate(nil, { controller: 'foo', action: 'bar', id: '10' }, {})
        assert_equal '/foo/10', path

        assert_raises(ActionController::UrlGenerationError) do
          _generate(nil, { id: 'aa' }, {})
        end
      end

      def test_only_required_parts_are_verified
        get '/foo(/:id)', id: /\d/, to: 'foo#bar'

        path, _ = _generate(nil, { controller: 'foo', action: 'bar', id: '10' }, {})
        assert_equal '/foo/10', path

        path, _ = _generate(nil, { controller: 'foo', action: 'bar' }, {})
        assert_equal '/foo', path

        path, _ = _generate(nil, { controller: 'foo', action: 'bar', id: 'aa' }, {})
        assert_equal '/foo/aa', path
      end

      def test_knows_what_parts_are_missing_from_named_route
        route_name = 'gorby_thunderhorse'
        get '/foo/:id', as: route_name, id: /\d+/, to: 'foo#bar'

        error = assert_raises(ActionController::UrlGenerationError) do
          _generate(route_name, {}, {})
        end

        assert_match(/missing required keys: \[:id\]/, error.message)
      end

      def test_does_not_include_missing_keys_message
        route_name = 'gorby_thunderhorse'

        error = assert_raises(ActionController::UrlGenerationError) do
          _generate(route_name, {}, {})
        end

        assert_no_match(/missing required keys: \[\]/, error.message)
      end

      def test_X_Cascade
        get '/messages(.:format)', to: 'foo#bar'
        resp = router.serve(rails_env('REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/lol'))
        assert_equal ['Not Found'], resp.last
        assert_equal 'pass', resp[1]['X-Cascade']
        assert_equal 404, resp.first
      end

      def test_clear_trailing_slash_from_script_name_on_root_unanchored_routes
        app = lambda { |env| [200, {}, ['success!']] }
        get '/weblog', to: app

        env  = rack_env('SCRIPT_NAME' => '', 'PATH_INFO' => '/weblog')
        resp = route_set.call env
        assert_equal ['success!'], resp.last
        assert_equal '', env['SCRIPT_NAME']
      end

      def test_defaults_merge_correctly
        get '/foo(/:id)', to: 'foo#bar', id: nil

        env = rails_env 'PATH_INFO' => '/foo/10'
        router.recognize(env) do |r, params|
          assert_equal({ id: '10', controller: 'foo', action: 'bar' }, params)
        end

        env = rails_env 'PATH_INFO' => '/foo'
        router.recognize(env) do |r, params|
          assert_equal({ id: nil, controller: 'foo', action: 'bar' }, params)
        end
      end

      def test_recognize_with_unbound_regexp
        get '/foo', anchor: false, to: 'foo#bar'

        env = rails_env 'PATH_INFO' => '/foo/bar'

        router.recognize(env) { |*_| }

        assert_equal '/foo', env.env['SCRIPT_NAME']
        assert_equal '/bar', env.env['PATH_INFO']
      end

      def test_bound_regexp_keeps_path_info
        get '/foo', to: 'foo#bar'

        env = rails_env 'PATH_INFO' => '/foo'

        before = env.env['SCRIPT_NAME']

        router.recognize(env) { |*_| }

        assert_equal before, env.env['SCRIPT_NAME']
        assert_equal '/foo', env.env['PATH_INFO']
      end

      def test_path_not_found
        [
          '/messages(.:format)',
          '/messages/new(.:format)',
          '/messages/:id/edit(.:format)',
          '/messages/:id(.:format)'
        ].each do |path|
          get path, to: 'foo#bar'
        end
        env = rails_env 'PATH_INFO' => '/messages/unknown/path'
        yielded = false

        router.recognize(env) do |*whatever|
          yielded = true
        end
        assert_not yielded
      end

      def test_required_part_in_recall
        get '/messages/:a/:b', to: 'foo#bar'

        path, _ = _generate(nil, { controller: 'foo', action: 'bar', a: 'a' }, { b: 'b' })
        assert_equal '/messages/a/b', path
      end

      def test_splat_in_recall
        get '/*path', to: 'foo#bar'

        path, _ = _generate(nil, { controller: 'foo', action: 'bar' }, { path: 'b' })
        assert_equal '/b', path
      end

      def test_recall_should_be_used_when_scoring
        get '/messages/:action(/:id(.:format))', to: 'foo#bar'
        get '/messages/:id(.:format)', to: 'bar#baz'

        path, _ = _generate(nil, { controller: 'foo', id: 10 }, { action: 'index' })
        assert_equal '/messages/index/10', path
      end

      def test_nil_path_parts_are_ignored
        get '/:controller(/:action(.:format))', to: 'tasks#lol'

        params = { controller: 'tasks', format: nil }
        extras = { action: 'lol' }

        path, _ = _generate(nil, params, extras)
        assert_equal '/tasks/index', path
      end

      def test_generate_slash
        params = [ [:controller, 'tasks'],
                   [:action, 'show'] ]
        get '/', Hash[params]

        path, _ = _generate(nil, Hash[params], {})
        assert_equal '/', path
      end

      def test_generate_id
        get '/:controller(/:action)', to: 'foo#bar'

        path, params = _generate(
          nil, { id: 1, controller: 'tasks', action: 'show' }, {})
        assert_equal '/tasks/show', path
        assert_equal({ id: '1' }, params)
      end

      def test_generate_escapes
        get '/:controller(/:action)', to: 'foo#bar'

        path, _ = _generate(nil,
          { controller: 'tasks',
                 action: 'a/b c+d',
        }, {})
        assert_equal '/tasks/a%2Fb%20c+d', path
      end

      def test_generate_escapes_with_namespaced_controller
        get '/:controller(/:action)', to: 'foo#bar'

        path, _ = _generate(
          nil, { controller: 'admin/tasks',
                 action: 'a/b c+d',
        }, {})
        assert_equal '/admin/tasks/a%2Fb%20c+d', path
      end

      def test_generate_extra_params
        get '/:controller(/:action)', to: 'foo#bar'

        path, params = _generate(
          nil, { id: 1,
                 controller: 'tasks',
                 action: 'show',
                 relative_url_root: nil
        }, {})
        assert_equal '/tasks/show', path
        assert_equal({ id: '1' }, params)
      end

      def test_generate_missing_keys_no_matches_different_format_keys
        get '/:controller/:action/:name', to: 'foo#bar'
        primary_parameters = {
          id: 1,
          controller: 'tasks',
          action: 'show',
          relative_url_root: nil
        }
        redirection_parameters = {
          'action' => 'show',
        }
        missing_key = 'name'
        missing_parameters = {
          missing_key => 'task_1'
        }
        request_parameters = primary_parameters.merge(redirection_parameters).merge(missing_parameters)

        message = "No route matches #{Hash[request_parameters.sort_by { |k, _|k.to_s }].inspect}, missing required keys: #{[missing_key.to_sym].inspect}"

        error = assert_raises(ActionController::UrlGenerationError) do
          _generate(
            nil, request_parameters, request_parameters)
        end
        assert_equal message, error.message
      end

      def test_generate_uses_recall_if_needed
        get '/:controller(/:action(/:id))', to: 'foo#bar'

        path, params = _generate(
          nil,
          { controller: 'tasks', id: 10 },
          { action: 'index' })
        assert_equal '/tasks/index/10', path
        assert_equal({}, params)
      end

      def test_generate_with_name
        get '/:controller(/:action)', to: 'foo#bar', as: 'tasks'

        path, params = _generate(
          'tasks',
          { controller: 'tasks' },
          { controller: 'tasks', action: 'index' })
        assert_equal '/tasks/index', path
        assert_equal({}, params)
      end

      {
        '/content'          => { controller: 'content' },
        '/content/list'     => { controller: 'content', action: 'list' },
        '/content/show/10'  => { controller: 'content', action: 'show', id: '10' },
      }.each do |request_path, expected|
        define_method("test_recognize_#{expected.keys.map(&:to_s).join('_')}") do
          get '/:controller(/:action(/:id))', to: 'foo#bar'
          route = @routes.first

          env = rails_env 'PATH_INFO' => request_path
          called = false

          router.recognize(env) do |r, params|
            assert_equal route, r
            assert_equal({ action: 'bar' }.merge(expected), params)
            called = true
          end

          assert called
        end
      end

      {
        segment: ['/a%2Fb%20c+d/splat', { segment: 'a/b c+d', splat: 'splat'   }],
        splat: ['/segment/a/b%20c+d', { segment: 'segment', splat: 'a/b c+d' }]
      }.each do |name, (request_path, expected)|
        define_method("test_recognize_#{name}") do
          get '/:segment/*splat', to: 'foo#bar'

          env = rails_env 'PATH_INFO' => request_path
          called = false
          route = @routes.first

          router.recognize(env) do |r, params|
            assert_equal route, r
            assert_equal(expected.merge(controller: 'foo', action: 'bar'), params)
            called = true
          end

          assert called
        end
      end

      def test_namespaced_controller
        get '/:controller(/:action(/:id))', controller: /.+?/
        route = @routes.first

        env = rails_env 'PATH_INFO' => '/admin/users/show/10'
        called   = false
        expected = {
          controller: 'admin/users',
          action: 'show',
          id: '10'
        }

        router.recognize(env) do |r, params|
          assert_equal route, r
          assert_equal(expected, params)
          called = true
        end
        assert called
      end

      def test_recognize_literal
        get '/books(/:action(.:format))', controller: 'books'
        route = @routes.first

        env = rails_env 'PATH_INFO' => '/books/list.rss'
        expected = { controller: 'books', action: 'list', format: 'rss' }
        called = false
        router.recognize(env) do |r, params|
          assert_equal route, r
          assert_equal(expected, params)
          called = true
        end

        assert called
      end

      def test_recognize_head_route
        match '/books(/:action(.:format))', via: 'head', to: 'foo#bar'

        env = rails_env(
          'PATH_INFO' => '/books/list.rss',
          'REQUEST_METHOD' => 'HEAD'
        )

        called = false
        router.recognize(env) do |r, params|
          called = true
        end

        assert called
      end

      def test_recognize_head_request_as_get_route
        get '/books(/:action(.:format))', to: 'foo#bar'

        env = rails_env 'PATH_INFO' => '/books/list.rss',
                        'REQUEST_METHOD' => 'HEAD'

        called = false
        router.recognize(env) do |r, params|
          called = true
        end

        assert called
      end

      def test_recognize_cares_about_get_verbs
        match '/books(/:action(.:format))', to: 'foo#bar', via: :get

        env = rails_env 'PATH_INFO' => '/books/list.rss',
                        'REQUEST_METHOD' => 'POST'

        called = false
        router.recognize(env) do |r, params|
          called = true
        end

        assert_not called
      end

      def test_recognize_cares_about_post_verbs
        match '/books(/:action(.:format))', to: 'foo#bar', via: :post

        env = rails_env 'PATH_INFO' => '/books/list.rss',
                        'REQUEST_METHOD' => 'POST'

        called = false
        router.recognize(env) do |r, params|
          called = true
        end

        assert called
      end

      def test_multi_verb_recognition
        match '/books(/:action(.:format))', to: 'foo#bar', via: [:post, :get]

        %w( POST GET ).each do |verb|
          env = rails_env 'PATH_INFO' => '/books/list.rss',
            'REQUEST_METHOD' => verb

          called = false
          router.recognize(env) do |r, params|
            called = true
          end

          assert called
        end

        env = rails_env 'PATH_INFO' => '/books/list.rss',
          'REQUEST_METHOD' => 'PUT'

        called = false
        router.recognize(env) do |r, params|
          called = true
        end

        assert_not called
      end

      def test_eager_load_with_routes
        get '/foo-bar', to: 'foo#bar'
        assert_nil router.eager_load!
      end

      def test_eager_load_without_routes
        assert_nil router.eager_load!
      end

      private
        def _generate(route_name, options, recall)
          if recall
            options = options.merge(_recall: recall)
          end
          path = @route_set.path_for(options, route_name)
          uri = URI.parse path
          params = Rack::Utils.parse_nested_query(uri.query).symbolize_keys
          [uri.path, params]
        end

        def get(*args)
          ActiveSupport::Deprecation.silence do
            mapper.get(*args)
          end
        end

        def match(*args)
          ActiveSupport::Deprecation.silence do
            mapper.match(*args)
          end
        end

        def rails_env(env, klass = ActionDispatch::Request)
          klass.new(rack_env(env))
        end

        def rack_env(env)
          {
            'rack.version'      => [1, 1],
            'rack.input'        => StringIO.new,
            'rack.errors'       => StringIO.new,
            'rack.multithread'  => true,
            'rack.multiprocess' => true,
            'rack.run_once'     => false,
            'REQUEST_METHOD'    => 'GET',
            'SERVER_NAME'       => 'example.org',
            'SERVER_PORT'       => '80',
            'QUERY_STRING'      => '',
            'PATH_INFO'         => '/content',
            'rack.url_scheme'   => 'http',
            'HTTPS'             => 'off',
            'SCRIPT_NAME'       => '',
            'CONTENT_LENGTH'    => '0'
          }.merge env
        end
    end
  end
end
