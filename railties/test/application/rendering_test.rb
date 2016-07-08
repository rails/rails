require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class RoutingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "Unknown format falls back to HTML template" do
      app_file 'config/routes.rb', <<-RUBY
        Rails.application.routes.draw do
          get 'pages/:id', to: 'pages#show'
        end
      RUBY

      app_file 'app/controllers/pages_controller.rb', <<-RUBY
        class PagesController < ApplicationController
          layout false

          def show
          end
        end
      RUBY

      app_file 'app/views/pages/show.html.erb', <<-RUBY
        <%= params[:id] %>
      RUBY

      get '/pages/foo'
      assert_equal 200, last_response.status

      get '/pages/foo.bar'
      assert_equal 200, last_response.status
    end
  end
end
