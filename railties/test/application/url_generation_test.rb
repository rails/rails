# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class UrlGenerationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def app
      Rails.application
    end

    test "it works" do
      require "rails"
      require "action_controller/railtie"
      require "action_view/railtie"

      class MyApp < Rails::Application
        config.session_store :cookie_store, key: "_myapp_session"
        config.active_support.deprecation = :log
        config.eager_load = false
      end

      Rails.application.initialize!

      class ::ApplicationController < ActionController::Base
      end

      class ::OmgController < ::ApplicationController
        def index
          render plain: omg_path
        end
      end

      MyApp.routes.draw do
        get "/" => "omg#index", as: :omg
      end

      require "rack/test"
      extend Rack::Test::Methods

      get "/"
      assert_equal "/", last_response.body
    end

    def test_routes_know_the_relative_root
      require "rails"
      require "action_controller/railtie"
      require "action_view/railtie"

      relative_url = "/hello"
      ENV["RAILS_RELATIVE_URL_ROOT"] = relative_url
      app = Class.new(Rails::Application)
      assert_equal relative_url, app.routes.relative_url_root
      ENV["RAILS_RELATIVE_URL_ROOT"] = nil
    end
  end
end
