# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "env_helpers"

module ApplicationTests
  class BacktraceCleanerTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods
    include EnvHelpers

    def teardown
      teardown_app
    end

    test "backtrace is cleaned" do
      setup_app

      app("development")
      get "/"
      if RUBY_VERSION >= "3.4"
        assert_includes last_response.body, "app/app/controllers/foo_controller.rb:4:in 'FooController#index'"
      else
        assert_includes last_response.body, "app/app/controllers/foo_controller.rb:4:in `index'"
      end
      assert_not_includes last_response.body, "rails/railties/test/env_helpers.rb"
    end

    test "backtrace is not cleaned" do
      switch_env("BACKTRACE", "1") do
        setup_app

        app("development")
        get "/"
        if RUBY_VERSION >= "3.4"
          assert_includes last_response.body, "app/app/controllers/foo_controller.rb:4:in 'FooController#index'"
        else
          assert_includes last_response.body, "app/app/controllers/foo_controller.rb:4:in `index'"
        end
        assert_includes last_response.body, "rails/railties/test/env_helpers.rb"
      end
    end

    private
      def setup_app
        build_app

        controller :foo, <<-RUBY
          class FooController < ApplicationController
            def index
              begin
                raise "ERROR"
              rescue StandardError => e
                render plain: e.backtrace.join("\n")
              end
            end
          end
        RUBY

        app_file "config/routes.rb", <<-RUBY
          Rails.application.routes.draw do
            root to: "foo#index"
          end
        RUBY
      end
  end
end
