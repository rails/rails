# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class ReportingEndpointsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "default reporting endpoints header is nil" do
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

      assert_equal 200, last_response.status
      assert_header_absent
    end

    test "empty reporting endpoints header is generated" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/reporting_endpoints.rb", <<-RUBY
        Rails.application.config.reporting_endpoints do |e|
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
      assert_header_present ""
    end

    test "no initializer with controller override" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          reporting_endpoints do |e|
            e.endpoints = { "csp-reports": "https://example.biz" }
          end

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

      assert_equal 200, last_response.status
      assert_header_present "csp-reports=\"https://example.biz\""
    end

    test "global reporting endpoints in an initializer" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/reporting_endpoints.rb", <<-RUBY
        Rails.application.config.reporting_endpoints do |e|
          e.endpoints = { "csp-reports": "https://example.biz" }
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
      assert_header_present "csp-reports=\"https://example.biz\""
    end

    test "override reporting endpoints in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          reporting_endpoints do |e|
            e.endpoints = { "csp-reports": "https://example.biz" }
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/reporting_endpoints.rb", <<-RUBY
        Rails.application.config.reporting_endpoints do |e|
          e.endpoints = { "csp-reports": "https://example.pizza" }
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
      assert_header_present "csp-reports=\"https://example.biz\""
    end

    private
      def assert_header_present(value)
        assert_equal value, last_response.headers["Reporting-Endpoints"]
      end

      def assert_header_absent
        assert_nil last_response.headers["Reporting-Endpoints"]
      end
  end
end
