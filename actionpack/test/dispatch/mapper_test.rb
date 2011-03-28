require 'abstract_unit'

module ActionDispatch
  module Routing
    class MapperTest < ActiveSupport::TestCase
      class FakeSet
        attr_reader :routes

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
      end

      def test_initialize
        Mapper.new FakeSet.new
      end

      def test_map_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.match '/*path', :to => 'pages#show', :as => :page
        assert_equal '/*path', fakeset.conditions.first[:path_info]
      end

      def test_map_wildcard_with_other_element
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.match '/*path/foo/:bar', :to => 'pages#show', :as => :page
        assert_equal '/*path/foo/:bar(.:format)', fakeset.conditions.first[:path_info]
      end

      def test_map_wildcard_with_multiple_wildcard
        fakeset = FakeSet.new
        mapper = Mapper.new fakeset
        mapper.match '/*foo/*bar', :to => 'pages#show', :as => :page
        assert_equal '/*foo/*bar', fakeset.conditions.first[:path_info]
      end
    end
  end
end