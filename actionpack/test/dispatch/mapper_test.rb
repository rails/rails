require 'abstract_unit'

module ActionDispatch
  module Routing
    class MapperTest < ActiveSupport::TestCase
      class FakeSet
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

        def add_route(*args)
          routes << args
        end

        def conditions
          routes.map { |x| x[1] }
        end

        def requirements
          routes.map { |x| x[2] }
        end
      end

      def test_initialize
        Mapper.new FakeSet.new
      end

      def test_mapping_requirements
        options = { :controller => 'foo', :action => 'bar', :via => :get }
        m = Mapper::Mapping.new FakeSet.new, {}, '/store/:name(*rest)', options
        _, _, requirements, _ = m.to_route
        assert_equal(/.+?/, requirements[:rest])
      end

      def test_map_slash
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/', :to => 'posts#index', :as => :main
        assert_equal '/', fakeset.conditions.first[:path_info]
      end

      def test_map_more_slashes
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset

        # FIXME: is this a desired behavior?
        mapper.get '/one/two/', :to => 'posts#index', :as => :main
        assert_equal '/one/two(.:format)', fakeset.conditions.first[:path_info]
      end

      def test_map_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', :to => 'pages#show'
        assert_equal '/*path(.:format)', fakeset.conditions.first[:path_info]
        assert_equal(/.+?/, fakeset.requirements.first[:path])
      end

      def test_map_wildcard_with_other_element
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path/foo/:bar', :to => 'pages#show'
        assert_equal '/*path/foo/:bar(.:format)', fakeset.conditions.first[:path_info]
        assert_nil fakeset.requirements.first[:path]
      end

      def test_map_wildcard_with_multiple_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*foo/*bar', :to => 'pages#show'
        assert_equal '/*foo/*bar(.:format)', fakeset.conditions.first[:path_info]
        assert_nil fakeset.requirements.first[:foo]
        assert_equal(/.+?/, fakeset.requirements.first[:bar])
      end

      def test_map_wildcard_with_format_false
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', :to => 'pages#show', :format => false
        assert_equal '/*path', fakeset.conditions.first[:path_info]
        assert_nil fakeset.requirements.first[:path]
      end

      def test_map_wildcard_with_format_true
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.get '/*path', :to => 'pages#show', :format => true
        assert_equal '/*path.:format', fakeset.conditions.first[:path_info]
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
