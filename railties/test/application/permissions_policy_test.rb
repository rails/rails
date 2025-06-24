# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class PermissionsPolicyTest < ActiveSupport::TestCase
    POLICY = ActionDispatch::Constants::FEATURE_POLICY

    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "permissions policy is not enabled by default" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"
      assert_nil last_response.headers[POLICY]
    end

    test "global permissions policy in an initializer" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/permissions_policy.rb", <<-RUBY
        Rails.application.config.permissions_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"
      assert_policy "geolocation 'none'"
    end

    test "override permissions policy using same directive in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          permissions_policy do |p|
            p.geolocation "https://example.com"
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/permissions_policy.rb", <<-RUBY
        Rails.application.config.permissions_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"
      assert_policy "geolocation https://example.com"
    end

    test "override permissions policy by unsetting a directive in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          permissions_policy do |p|
            p.geolocation nil
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/permissions_policy.rb", <<-RUBY
        Rails.application.config.permissions_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"
      assert_equal 200, last_response.status
      assert_nil last_response.headers[POLICY]
    end

    test "override permissions policy using different directives in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          permissions_policy do |p|
            p.geolocation nil
            p.payment     "https://secure.example.com"
            p.autoplay    :none
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/permissions_policy.rb", <<-RUBY
        Rails.application.config.permissions_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"
      assert_policy "payment https://secure.example.com; autoplay 'none'"
    end

    test "global permissions policy added to rack app" do
      app_file "config/initializers/permissions_policy.rb", <<-RUBY
        Rails.application.config.permissions_policy do |p|
          p.payment :none
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          app = ->(env) {
            [200, { Rack::CONTENT_TYPE => "text/html" }, ["<p>Hello, World!</p>"]]
          }
          root to: app
        end
      RUBY

      app("development")

      get "/"
      assert_policy "payment 'none'"
    end

    private
      def assert_policy(expected)
        assert_equal 200, last_response.status
        assert_equal expected, last_response.headers[POLICY]
      end
  end
end
