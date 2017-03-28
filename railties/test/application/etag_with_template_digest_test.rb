require "isolation/abstract_unit"
require "rack/test"
require "minitest/mock"

require "action_view"
require "active_support/testing/method_call_assertions"

class PerRequestDigestCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include ActiveSupport::Testing::MethodCallAssertions
  include Rack::Test::Methods

  setup do
    build_app

    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get "with_template" => "customers#with_template"
        get "with_implicit_template" => "customers#with_implicit_template"
        get "namespaced_implicit_template" => "namespaced/customers#with_implicit_template"
      end
    RUBY

    app_file "app/controllers/customers_controller.rb", <<-RUBY
      class CustomersController < ApplicationController
        def with_template
          if stale? template: "test/hello_world"
            render plain: "stale"
          end
        end

        def with_implicit_template
          fresh_when(etag: "123")
        end
      end
    RUBY

    app_file "app/controllers/namespaced/customers_controller.rb", <<-RUBY
      module Namespaced
        class CustomersController < ApplicationController
          def with_implicit_template
            fresh_when(etag: "abc")
          end
        end
      end
    RUBY

    app_file "app/views/test/hello_world.erb", <<-RUBY
      Hello World!
    RUBY

    app_file "app/views/customers/with_implicit_template.erb", <<-RUBY
      Hello explicitly!
    RUBY

    app_file "app/views/namespaced/customers/with_implicit_template.erb", <<-RUBY
      Hello explicitly and namespaced!
    RUBY

    require "#{app_path}/config/environment"
  end

  teardown :teardown_app

  test "etag reflects template digest" do
    get "/with_template"
    assert_equal 200, last_response.status
    assert_not_nil etag = last_response.etag

    get "/with_template", {}, "HTTP_IF_NONE_MATCH" => etag
    assert_equal 304, last_response.status

    app_file "app/views/test/hello_world.erb", <<-RUBY
      Hello World moddified!
    RUBY

    get "/with_template", {}, "HTTP_IF_NONE_MATCH" => etag
    assert_equal 200, last_response.status
    assert_not_equal etag, last_response.etag
  end

  test "etag reflects implicit template digest" do
    get "/with_implicit_template"
    assert_equal 200, last_response.status
    assert_not_nil etag = last_response.etag

    get "/with_implicit_template", {}, "HTTP_IF_NONE_MATCH" => etag
    assert_equal 304, last_response.status

    app_file "app/views/customers/with_implicit_template.erb", <<-RUBY
      Hello explicitly modified!
    RUBY

    get "/with_implicit_template", {}, "HTTP_IF_NONE_MATCH" => etag
    assert_equal 200, last_response.status
    assert_not_equal etag, last_response.etag
  end

  test "etag reflects namespacd template digest" do
    get "/namespaced_implicit_template"
    assert_equal 200, last_response.status
    assert_not_nil etag = last_response.etag

    get "/namespaced_implicit_template", {}, "HTTP_IF_NONE_MATCH" => etag
    assert_equal 304, last_response.status

    app_file "app/views/namespaced/customers/with_implicit_template.erb", <<-RUBY
      Hello explicitly and namespaced modified!
    RUBY

    get "/namespaced_implicit_template", {}, "HTTP_IF_NONE_MATCH" => etag
    assert_equal 200, last_response.status
    assert_not_equal etag, last_response.etag
  end
end
