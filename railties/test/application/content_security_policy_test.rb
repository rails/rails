# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class ContentSecurityPolicyTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    POLICY = "Content-Security-Policy"
    POLICY_REPORT_ONLY = "Content-Security-Policy-Report-Only"

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "default content security policy is nil" do
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
      assert_policy_absent POLICY
      assert_policy_absent POLICY_REPORT_ONLY
    end

    test "empty content security policy is generated" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
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
      assert_policy_present ""
      assert_policy_absent POLICY_REPORT_ONLY
    end

    test "global content security policy in an initializer" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src :self, :https
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
      assert_policy_present "default-src 'self' https:"
      assert_policy_absent POLICY_REPORT_ONLY
    end

    test "global content security policy report only in an initializer with boolean" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src :self, :https
        end

        Rails.application.config.content_security_policy_report_only = true
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"

      assert_equal 200, last_response.status
      assert_policy_present "default-src 'self' https:", report_only: true
      assert_policy_absent POLICY
    end

    test "global content security policy report only in an initializer with block" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy_report_only do |p|
          p.default_src :self, :https
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
      assert_policy_present "default-src 'self' https:", report_only: true
      assert_policy_absent POLICY
    end

    test "global content security policy and content security policy report only in an initializer" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src :self, :https
        end
        Rails.application.config.content_security_policy_report_only do |p|
          p.default_src :self, :https
          p.script_src  :self, :https
          p.style_src   :self, :https
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
      assert_policy_present "default-src 'self' https:"
      assert_policy_present "default-src 'self' https:; script-src 'self' https:; style-src 'self' https:", report_only: true
    end

    test "global content security policy nonce directives in an initializer" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src :self, :https
          p.script_src  :self, :https
          p.style_src   :self, :https
        end

        Rails.application.config.content_security_policy_nonce_generator = proc { "iyhD0Yc0W+c=" }
        Rails.application.config.content_security_policy_nonce_directives = %w(script-src)
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"

      assert_equal 200, last_response.status
      assert_policy_present "default-src 'self' https:; script-src 'self' https: 'nonce-iyhD0Yc0W+c='; style-src 'self' https:"
      assert_policy_absent POLICY_REPORT_ONLY
    end

    test "override content security policy in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          content_security_policy do |p|
            p.default_src "https://example.com"
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src :self, :https
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
      assert_policy_present "default-src https://example.com"
      assert_policy_absent POLICY_REPORT_ONLY
    end

    test "override content security policy to report only in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          content_security_policy_report_only

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src "https://example.com"
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
      assert_policy_present "default-src https://example.com", report_only: true
      assert_policy_absent POLICY
    end

    test "set content security policy report only in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          content_security_policy_report_only do |p|
            p.default_src "https://example.com"
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"

      assert_equal 200, last_response.status
      assert_policy_present "default-src https://example.com", report_only: true
      assert_policy_absent POLICY
    end

    test "override content security policy report only in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          content_security_policy_report_only do |p|
            p.default_src "https://example.com"
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src "https://host.com"
        end

        Rails.application.config.content_security_policy_report_only do |p|
          p.default_src :self, :https
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
      assert_policy_present "default-src https://example.com", report_only: true
      assert_policy_present "default-src https://host.com"
    end

    test "override content security policy and content security policy report only in a controller" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          content_security_policy do |p|
            p.default_src "https://example.com", :https
          end

          content_security_policy_report_only do |p|
            p.default_src "https://example.com", :https
            p.script_src  "https://example.com", :https
            p.style_src   "https://example.com", :https
          end

          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src "https://host.com"
        end

        Rails.application.config.content_security_policy_report_only = true
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"

      assert_equal 200, last_response.status
      assert_policy_present "default-src https://example.com https:; script-src https://example.com https:; style-src https://example.com https:", report_only: true
      assert_policy_present "default-src https://example.com https:"
    end

    test "global content security policy added to rack app" do
      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy do |p|
          p.default_src :self, :https
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do

          app = ->(env) {
            [200, { "Content-Type" => "text/html" }, ["<p>Hello, World!</p>"]]
          }

          root to: app
        end
      RUBY

      app("development")

      get "/"

      assert_equal 200, last_response.status
      assert_policy_present "default-src 'self' https:"
      assert_policy_absent POLICY_REPORT_ONLY
    end

    test "global report only content security policy added to rack app" do
      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.config.content_security_policy_report_only do |p|
          p.default_src :self, :https
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do

          app = ->(env) {
            [200, { "Content-Type" => "text/html" }, ["<p>Hello, World!</p>"]]
          }

          root to: app
        end
      RUBY

      app("development")

      get "/"

      assert_equal 200, last_response.status
      assert_policy_present "default-src 'self' https:", report_only: true
      assert_policy_absent POLICY
    end

    private
      def assert_policy_present(expected, report_only: false)
        if report_only
          expected_header = "Content-Security-Policy-Report-Only"
        else
          expected_header = "Content-Security-Policy"
        end

        assert_equal expected, last_response.headers[expected_header]
      end

      def assert_policy_absent(header_name)
        assert_nil last_response.headers[header_name]
      end
  end
end
