require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class RoutingTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      boot_rails
    end

    def app
      @app ||= Rails.application
    end

    test "assets routes have higher priority" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          match '*path', :to => lambda { |env| [200, { "Content-Type" => "text/html" }, "Not an asset"] }
        end
      RUBY

      require "#{app_path}/config/environment"

      get "/assets/demo.js"
      assert_match "alert()", last_response.body
    end

    test "does not stream session cookies back" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          match '/omg', :to => "omg#index"
        end
      RUBY

      require "#{app_path}/config/environment"

      class ::OmgController < ActionController::Base
        def index
          flash[:cool_story] = true
          render :text => "ok"
        end
      end

      get "/omg"
      assert_equal 'ok', last_response.body

      get "/assets/demo.js"
      assert_match "alert()", last_response.body
      assert_equal nil, last_response.headers["Set-Cookie"]
    end
  end
end
