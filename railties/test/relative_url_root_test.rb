# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module RailtiesTest
  class EngineTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    setup do
      build_app

      app_file "app/controllers/application_controller.rb", <<-RUBY
        class ApplicationController < ActionController::Base
          def welcome
            render plain: root_path
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: "application#welcome"
        end
      RUBY
    end

    teardown do
      teardown_app
    end

    test "application routes are properly generated when relative_url_root is set" do
      add_to_env_config "development", "config.relative_url_root = '/foo'"
      boot_rails

      root_path = rails("runner", "p Rails.application.routes.url_helpers.root_path").chomp

      assert_equal "\"/foo/\"", root_path
    end

    test "controller routes are properly generated when relative_url_root is set" do
      add_to_env_config "development", "config.relative_url_root = '/foo'"
      boot_rails

      get "/"
      assert_equal "/foo/", last_response.body
    end

  private
    def boot_rails
      require "#{app_path}/config/environment"
    end
  end
end
