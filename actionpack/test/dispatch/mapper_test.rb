# frozen_string_literal: true

require 'abstract_unit'

module ActionDispatch
  module Routing
    class MapperTest < ActiveSupport::TestCase
      class FakeSet < ActionDispatch::Routing::RouteSet
        def resources_path_names
          {}
        end

        def request_class
          ActionDispatch::Request
        end

        def dispatcher_class
          RouteSet::Dispatcher
        end

        def defaults
          routes.map(&:defaults)
        end

        def conditions
          routes.map(&:constraints)
        end

        def requirements
          routes.map(&:path).map(&:requirements)
        end

        def asts
          routes.map(&:path).map(&:spec)
        end
      end

      def test_initialize
        Mapper.new FakeSet.new
      end

      def test_scope_raises_on_anchor
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        assert_raises(ArgumentError) do
          mapper.scope(anchor: false) do
          end
        end
      end

      def test_blows_up_without_via
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        assert_raises(ArgumentError) do
          mapper.match '/', to: 'posts#index', as: :main
        end
      end

      def test_unscoped_formatted
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/foo', to: 'posts#index', as: :main, format: true
        assert_equal({ controller: 'posts', action: 'index' },
                     fakeset.defaults.first)
        assert_equal '/foo.:format', fakeset.asts.first.to_s
      end

      def test_scoped_formatted
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.scope(format: true) do
          mapper.get '/foo', to: 'posts#index', as: :main
        end
        assert_equal({ controller: 'posts', action: 'index' },
                     fakeset.defaults.first)
        assert_equal '/foo.:format', fakeset.asts.first.to_s
      end

      def test_random_keys
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.scope(omg: :awesome) do
          mapper.get '/', to: 'posts#index', as: :main
        end
        assert_equal({ omg: :awesome, controller: 'posts', action: 'index' },
                     fakeset.defaults.first)
        assert_equal('GET', fakeset.routes.first.verb)
      end

      def test_mapping_requirements
        options = {}
        scope = Mapper::Scope.new({})
        ast = Journey::Parser.parse '/store/:name(*rest)'
        m = Mapper::Mapping.build(scope, FakeSet.new, ast, 'foo', 'bar', nil, [:get], nil, {}, true, options)
        assert_equal(/.+?/, m.requirements[:rest])
      end

      def test_via_scope
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.scope(via: :put) do
          mapper.match '/', to: 'posts#index', as: :main
        end
        assert_equal('PUT', fakeset.routes.first.verb)
      end

      def test_to_scope
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.scope(to: 'posts#index') do
          mapper.get :all
          mapper.post :most
        end

        assert_equal 'posts#index', fakeset.routes.to_a[0].defaults[:to]
        assert_equal 'posts#index', fakeset.routes.to_a[1].defaults[:to]
      end

      def test_map_slash
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/', to: 'posts#index', as: :main
        assert_equal '/', fakeset.asts.first.to_s
      end

      def test_map_more_slashes
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset

        # FIXME: is this a desired behavior?
        mapper.get '/one/two/', to: 'posts#index', as: :main
        assert_equal '/one/two(.:format)', fakeset.asts.first.to_s
      end

      def test_map_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', to: 'pages#show'
        assert_equal '/*path(.:format)', fakeset.asts.first.to_s
        assert_equal(/.+?/, fakeset.requirements.first[:path])
      end

      def test_map_wildcard_with_other_element
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path/foo/:bar', to: 'pages#show'
        assert_equal '/*path/foo/:bar(.:format)', fakeset.asts.first.to_s
        assert_equal(/.+?/, fakeset.requirements.first[:path])
      end

      def test_map_wildcard_with_multiple_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*foo/*bar', to: 'pages#show'
        assert_equal '/*foo/*bar(.:format)', fakeset.asts.first.to_s
        assert_equal(/.+?/, fakeset.requirements.first[:foo])
        assert_equal(/.+?/, fakeset.requirements.first[:bar])
      end

      def test_map_wildcard_with_format_false
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', to: 'pages#show', format: false
        assert_equal '/*path', fakeset.asts.first.to_s
        assert_nil fakeset.requirements.first[:path]
      end

      def test_map_wildcard_with_format_true
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', to: 'pages#show', format: true
        assert_equal '/*path.:format', fakeset.asts.first.to_s
      end

      def test_raising_error_when_path_is_not_passed
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        app = lambda { |env| [200, {}, ['']] }
        assert_raises ArgumentError do
          mapper.mount app
        end
      end

      def test_raising_error_when_rack_app_is_not_passed
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        assert_raises ArgumentError do
          mapper.mount 10, as: 'exciting'
        end

        assert_raises ArgumentError do
          mapper.mount as: 'exciting'
        end
      end

      def test_scope_does_not_destructively_mutate_default_options
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset

        frozen = { foo: :bar }.freeze

        assert_nothing_raised do
          mapper.scope(defaults: frozen) do
            # pass
          end
        end
      end
    end
  end
end
