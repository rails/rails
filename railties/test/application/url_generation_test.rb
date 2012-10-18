require 'isolation/abstract_unit'

module ApplicationTests
  class UrlGenerationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def app
      Rails.application
    end

    test "it works" do
      boot_rails
      require "rails"
      require "action_controller/railtie"

      class MyApp < Rails::Application
        config.secret_token = "3b7cd727ee24e8444053437c36cc66c4"
        config.session_store :cookie_store, key: "_myapp_session"
        config.active_support.deprecation = :log
        config.eager_load = false
      end

      MyApp.initialize!

      class ::ApplicationController < ActionController::Base
      end

      class ::OmgController < ::ApplicationController
        def index
          render text: omg_path
        end
      end

      MyApp.routes.draw do
        get "/" => "omg#index", as: :omg
      end

      require 'rack/test'
      extend Rack::Test::Methods

      get "/"
      assert_equal "/", last_response.body
    end
  end
end
