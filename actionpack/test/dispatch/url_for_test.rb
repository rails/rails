require 'abstract_unit'

module UrlForGeneration
  class UrlForTest < ActionDispatch::IntegrationTest

    Routes = ActionDispatch::Routing::RouteSet.new
    Routes.draw { match "/foo", :to => "my_route_generating#index", :as => :foo }

    class BlogEngine
      def self.routes
        @routes ||= begin
          routes = ActionDispatch::Routing::RouteSet.new
          routes.draw do
            resources :posts
          end
          routes
        end
      end
    end

    class Post
      extend ActiveModel::Naming

      def to_param
        "1"
      end

      def self.model_name
        klass = "Post"
        def klass.name; self end

        ActiveModel::Name.new(klass)
      end
    end

    include Routes.url_helpers

    test "url_for with named url helpers" do
      assert_equal "/posts", url_for(BlogEngine, :posts_path)
    end

    test "url_for with polymorphic routes" do
      assert_equal "http://www.example.com/posts/1", url_for(BlogEngine, Post.new)
    end

    test "url_for with named url helper with arguments" do
      assert_equal "/posts/1", url_for(BlogEngine, :post_path, 1)
      assert_equal "/posts/1", url_for(BlogEngine, :post_path, :id => 1)
      assert_equal "/posts/1.json", url_for(BlogEngine, :post_path, :id => 1, :format => :json)
    end
  end
end
