require 'abstract_unit'

module ActionDispatch
  module Routing
    class MapperTest < ActiveSupport::TestCase
      class FakeSet < ActionDispatch::Routing::RouteSet
        attr_reader :routes
        alias :set :routes

        def initialize
          @routes = []
        end

        def resources_path_names
          {}
        end

        def request_class
          ActionDispatch::Request
        end

        def dispatcher_class
          RouteSet::Dispatcher
        end

        def add_route(*args)
          routes << args
        end

        def defaults
          routes.map { |x| x[3] }
        end

        def conditions
          routes.map { |x| x[1] }
        end

        def requirements
          routes.map { |x| x[2] }
        end

        def asts
          conditions.map { |hash| hash[:parsed_path_info] }
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
          mapper.match '/', :to => 'posts#index', :as => :main
        end
      end

      def test_unscoped_formatted
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/foo', :to => 'posts#index', :as => :main, :format => true
        assert_equal({:controller=>"posts", :action=>"index"},
                     fakeset.defaults.first)
        assert_equal "/foo.:format", fakeset.asts.first.to_s
      end

      def test_scoped_formatted
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.scope(format: true) do
          mapper.get '/foo', :to => 'posts#index', :as => :main
        end
        assert_equal({:controller=>"posts", :action=>"index"},
                     fakeset.defaults.first)
        assert_equal "/foo.:format", fakeset.asts.first.to_s
      end

      def test_random_keys
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.scope(omg: :awesome) do
          mapper.get '/', :to => 'posts#index', :as => :main
        end
        assert_equal({:omg=>:awesome, :controller=>"posts", :action=>"index"},
                     fakeset.defaults.first)
        assert_equal ["GET"], fakeset.conditions.first[:request_method]
      end

      def test_mapping_requirements
        options = { }
        scope = Mapper::Scope.new({})
        m = Mapper::Mapping.build(scope, FakeSet.new, '/store/:name(*rest)', 'foo', 'bar', nil, [:get], nil, {}, options)
        _, _, requirements, _ = m.to_route
        assert_equal(/.+?/, requirements[:rest])
      end

      def test_via_scope
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.scope(via: :put) do
          mapper.match '/', :to => 'posts#index', :as => :main
        end
        assert_equal ["PUT"], fakeset.conditions.first[:request_method]
      end

      def test_map_slash
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/', :to => 'posts#index', :as => :main
        assert_equal '/', fakeset.asts.first.to_s
      end

      def test_map_more_slashes
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset

        # FIXME: is this a desired behavior?
        mapper.get '/one/two/', :to => 'posts#index', :as => :main
        assert_equal '/one/two(.:format)', fakeset.asts.first.to_s
      end

      def test_map_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', :to => 'pages#show'
        assert_equal '/*path(.:format)', fakeset.asts.first.to_s
        assert_equal(/.+?/, fakeset.requirements.first[:path])
      end

      def test_map_wildcard_with_other_element
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path/foo/:bar', :to => 'pages#show'
        assert_equal '/*path/foo/:bar(.:format)', fakeset.asts.first.to_s
        assert_equal(/.+?/, fakeset.requirements.first[:path])
      end

      def test_map_wildcard_with_multiple_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*foo/*bar', :to => 'pages#show'
        assert_equal '/*foo/*bar(.:format)', fakeset.asts.first.to_s
        assert_equal(/.+?/, fakeset.requirements.first[:foo])
        assert_equal(/.+?/, fakeset.requirements.first[:bar])
      end

      def test_map_wildcard_with_format_false
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', :to => 'pages#show', :format => false
        assert_equal '/*path', fakeset.asts.first.to_s
        assert_nil fakeset.requirements.first[:path]
      end

      def test_map_wildcard_with_format_true
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', :to => 'pages#show', :format => true
        assert_equal '/*path.:format', fakeset.asts.first.to_s
      end

      def test_raising_helpful_error_on_invalid_arguments
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        app = lambda { |env| [200, {}, [""]] }
        assert_raises ArgumentError do
          mapper.mount app
        end
      end
    end
  end
end
