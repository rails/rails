# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class ContentSecurityPolicyTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

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
      assert_nil last_response.headers["Content-Security-Policy"]
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
      assert_policy ""
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
      assert_policy "default-src 'self' https:"
    end

    test "global report only content security policy in an initializer" do
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
      assert_policy "default-src 'self' https:", report_only: true
    end

    test "global content security policy nonce directives in an initializer" do
      controller :pages, <<-RUBY
        class PagesController < ApplicationController
          def index
            render html: "<h1>Welcome to Rails!</h1>"
          end
        end
      RUBY

      # This should match the default in
      # ~/railties/lib/rails/generators/rails/app/templates/config/initializers/content_security_policy.rb.tt
      app_file "config/initializers/content_security_policy.rb", <<-RUBY
        Rails.application.configure do
          config.content_security_policy do |policy|
            policy.default_src :self, :https
            policy.font_src    :self, :https, :data
            policy.img_src     :self, :https, :data
            policy.object_src  :none
            policy.script_src  :self, :https
            policy.style_src   :self, :https
          end

          config.content_security_policy_nonce_generator = ->(request) { request.session.id || SecureRandom.hex(16) }
          config.content_security_policy_nonce_directives = %w(script-src style-src)
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "pages#index"
        end
      RUBY

      app("development")

      get "/"
      assert_policy %r{default-src 'self' https:; font-src 'self' https: data:; img-src 'self' https: data:; object-src 'none'; script-src 'self' https: 'nonce-([a-z0-9]+)'; style-src 'self' https: 'nonce-([a-z0-9]+)'}
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
      assert_policy "default-src https://example.com"
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
      assert_policy "default-src 'self' https:", report_only: true
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
      assert_policy "default-src 'self' https:"
    end

    private
      def assert_policy(expected, report_only: false)
        assert_equal 200, last_response.status

        if report_only
          expected_header = "Content-Security-Policy-Report-Only"
          unexpected_header = "Content-Security-Policy"
        else
          expected_header = "Content-Security-Policy"
          unexpected_header = "Content-Security-Policy-Report-Only"
        end

        assert_nil last_response.headers[unexpected_header]
        assert_match expected, last_response.headers[expected_header]
      end
  end
end
