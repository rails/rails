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

      get("/pages/foo", {}, "HTTPS" => "on")
      assert_equal 200, last_response.status

      get("/pages/foo.bar", {}, "HTTPS" => "on")
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
        ActiveSupport.on_load :action_view do
          ActionView::Template.register_template_handler(:rubby, RubbyHandler)
        end
      RUBY

      get("/", {}, "HTTPS" => "on")
      assert_equal 200, last_response.status
      assert_equal({ format: :awesome, handler: RubbyHandler }.inspect, last_response.body)
    end

    test "template content is dumped if rendered inline and a syntax error is encountered" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: 'pages#show'
        end
      RUBY

      app_file "app/controllers/pages_controller.rb", <<-RUBY
        class PagesController < ApplicationController
          layout false

          def show
            render(inline: "<% [ %>")
          end
        end
      RUBY

      app("development")

      get("/", {}, { "HTTPS" => "on" })

      assert_equal 500, last_response.status
      document = Nokogiri::HTML5.parse(last_response.body)
      nodes = document.css("div.exception-message>div.message")

      assert_not_empty(nodes)
      assert_equal("Encountered a syntax error while rendering template: check <% [ %>\n", nodes.first.text)
    end

    test "template content is not dumped when rendered from file and a syntax error is encountered" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          root to: 'pages#show'
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
        <% [ %>
      RUBY

      app("development")

      get("/", {}, { "HTTPS" => "on" })

      assert_equal 500, last_response.status
      document = Nokogiri::HTML5.parse(last_response.body)
      nodes = document.css("div.exception-message>div.message")

      assert_not_empty(nodes)
      assert_equal(
        "Encountered a syntax error while rendering template located at: app/views/pages/show.html.erb",
        nodes.first.text,
      )
    end
  end
end
