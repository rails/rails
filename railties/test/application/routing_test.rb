require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class RoutingTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def app
      @app ||= begin
        boot_rails
        require "#{app_path}/config/environment"

        Rails.application
      end
    end

    test "simple controller" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            render :text => "foo"
          end
        end
      RUBY

      get '/foo'
      assert_equal 'foo', last_response.body
    end

    test "multiple controllers" do
      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
            render :text => "foo"
          end
        end
      RUBY

      controller :bar, <<-RUBY
        class BarController < ActionController::Base
          def index
            render :text => "bar"
          end
        end
      RUBY

      get '/foo'
      assert_equal 'foo', last_response.body

      get '/bar'
      assert_equal 'bar', last_response.body
    end

    test "nested controller" do
      controller 'foo', <<-RUBY
        class FooController < ActionController::Base
          def index
            render :text => "foo"
          end
        end
      RUBY

      controller 'admin/foo', <<-RUBY
        module Admin
          class FooController < ActionController::Base
            def index
              render :text => "admin::foo"
            end
          end
        end
      RUBY

      get '/foo'
      assert_equal 'foo', last_response.body

      get '/admin/foo'
      assert_equal 'admin::foo', last_response.body
    end
  end
end
