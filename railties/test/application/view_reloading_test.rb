# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class ViewReloadingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'pages/:id', to: 'pages#show'
        end
      RUBY

      app_file "app/controllers/pages_controller.rb", <<-RUBY
        class PagesController < ApplicationController
          layout false

          def show
          end
        end
      RUBY
    end

    def teardown
      teardown_app
    end

    test "views are reloaded" do
      app_file "app/views/pages/show.html.erb", <<-RUBY
        Before!
      RUBY

      ENV["RAILS_ENV"] = "development"
      require "#{app_path}/config/environment"

      get "/pages/foo"
      get "/pages/foo"
      assert_equal 200, last_response.status, last_response.body
      assert_equal "Before!", last_response.body.strip

      app_file "app/views/pages/show.html.erb", <<-RUBY
        After!
      RUBY

      get "/pages/foo"
      assert_equal 200, last_response.status
      assert_equal "After!", last_response.body.strip
    end
  end
end
