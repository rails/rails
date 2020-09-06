# frozen_string_literal: true

require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class FeaturePolicyTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test 'feature policy is not enabled by default' do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app('development')

      get '/'
      assert_nil last_response.headers['Feature-Policy']
    end

    test 'global feature policy in an initializer' do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file 'config/initializers/feature_policy.rb', <<-RUBY
        Rails.application.config.feature_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app('development')

      get '/'
      assert_policy "geolocation 'none'"
    end

    test 'override feature policy using same directive in a controller' do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          feature_policy do |p|
            p.geolocation "https://example.com"
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file 'config/initializers/feature_policy.rb', <<-RUBY
        Rails.application.config.feature_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app('development')

      get '/'
      assert_policy 'geolocation https://example.com'
    end

    test 'override feature policy by unsetting a directive in a controller' do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          feature_policy do |p|
            p.geolocation nil
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file 'config/initializers/feature_policy.rb', <<-RUBY
        Rails.application.config.feature_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app('development')

      get '/'
      assert_equal 200, last_response.status
      assert_nil last_response.headers['Feature-Policy']
    end

    test 'override feature policy using different directives in a controller' do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          feature_policy do |p|
            p.geolocation nil
            p.payment     "https://secure.example.com"
            p.autoplay    :none
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file 'config/initializers/feature_policy.rb', <<-RUBY
        Rails.application.config.feature_policy do |p|
          p.geolocation :none
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app('development')

      get '/'
      assert_policy "payment https://secure.example.com; autoplay 'none'"
    end

    test 'global feature policy added to rack app' do
      app_file 'config/initializers/feature_policy.rb', <<-RUBY
        Rails.application.config.feature_policy do |p|
          p.payment :none
        end
      RUBY

      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          app = ->(env) {
            [200, { "Content-Type" => "text/html" }, ["<p>Hello, World!</p>"]]
          }
          root to: app
        end
      RUBY

      app('development')

      get '/'
      assert_policy "payment 'none'"
    end

    private
      def assert_policy(expected)
        assert_equal 200, last_response.status
        assert_equal expected, last_response.headers['Feature-Policy']
      end
  end
end
