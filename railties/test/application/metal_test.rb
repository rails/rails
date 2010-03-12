require 'isolation/abstract_unit'

module ApplicationTests
  class MetalTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails

      require 'rack/test'
      extend Rack::Test::Methods
    end

    def app
      @app ||= begin
        require "#{app_path}/config/environment"
        Rails.application
      end
    end

    test "single metal endpoint" do
      app_file 'app/metal/foo_metal.rb', <<-RUBY
        class FooMetal
          def self.call(env)
            [200, { "Content-Type" => "text/html"}, ["FooMetal"]]
          end
        end
      RUBY

      get "/not/slash"
      assert_equal 200, last_response.status
      assert_equal "FooMetal", last_response.body
    end

    test "multiple metal endpoints" do
      app_file 'app/metal/metal_a.rb', <<-RUBY
        class MetalA
          def self.call(env)
            [404, { "Content-Type" => "text/html", "X-Cascade" => "pass" }, ["Metal A"]]
          end
        end
      RUBY

      app_file 'app/metal/metal_b.rb', <<-RUBY
        class MetalB
          def self.call(env)
            [200, { "Content-Type" => "text/html"}, ["Metal B"]]
          end
        end
      RUBY

      get "/not/slash"
      assert_equal 200, last_response.status
      assert_equal "Metal B", last_response.body
    end

    test "pass through to application" do
      app_file 'app/metal/foo_metal.rb', <<-RUBY
        class FooMetal
          def self.call(env)
            [404, { "Content-Type" => "text/html", "X-Cascade" => "pass" }, ["Not Found"]]
          end
        end
      RUBY

      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            render :text => "foo"
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match ':controller(/:action)'
        end
      RUBY

      get "/foo"
      assert_equal 200, last_response.status
      assert_equal "foo", last_response.body
    end
  end
end
