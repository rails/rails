# encoding: utf-8
require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class ShowExceptionsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    test "unspecified route when set action_dispatch.show_exceptions to false" do
      app.config.action_dispatch.show_exceptions = false

      assert_raise(ActionController::RoutingError) do
        get '/foo'
      end
    end

    test "unspecified route when set action_dispatch.show_exceptions to true" do
      app.config.action_dispatch.show_exceptions = true

      assert_nothing_raised(ActionController::RoutingError) do
        get '/foo'
      end
    end

    test "displays diagnostics message when exception raised in template that contains UTF-8" do
      app.config.action_dispatch.show_exceptions = true

      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def index
          end
        end
      RUBY

      app_file 'app/views/foo/index.html.erb', <<-ERB
        <% raise 'boooom' %>
        ✓
      ERB

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          match ':controller(/:action)'
        end
      RUBY

      post '/foo', :utf8 => '✓'
      assert_match(/boooom/, last_response.body)
    end
  end
end
