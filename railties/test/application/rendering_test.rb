# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class RenderingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "Unknown format falls back to HTML template" do
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

      app_file "app/views/pages/show.html.erb", <<-RUBY
        <%= params[:id] %>
      RUBY

      get "/pages/foo"
      assert_equal 200, last_response.status

      get "/pages/foo.bar"
      assert_equal 200, last_response.status
    end

    test "New formats and handlers are detected from initializers" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: 'pages#show'
        end
      RUBY

      app_file "app/controllers/pages_controller.rb", <<-RUBY
        class PagesController < ApplicationController
          layout false

          def show
            render :show, formats: [:awesome], handlers: [:rubby]
          end
        end
      RUBY

      app_file "app/views/pages/show.awesome.rubby", <<-RUBY
        {
          format: @current_template.format,
          handler: @current_template.handler
        }.inspect
      RUBY

      app_file "config/initializers/mime_types.rb", <<-RUBY
        Mime::Type.register "text/awesome", :awesome
      RUBY

      app_file "config/initializers/template_handlers.rb", <<-RUBY
        module RubbyHandler
          def self.call(_, source)
            source
          end
        end
        ActionView::Template.register_template_handler(:rubby, RubbyHandler)
      RUBY

      get "/"
      assert_equal 200, last_response.status
      assert_equal "{:format=>:awesome, :handler=>RubbyHandler}", last_response.body
    end
  end
end
