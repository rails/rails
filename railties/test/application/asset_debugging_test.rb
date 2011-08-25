require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class AssetDebuggingTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(:initializers => true)

      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js", "function f1() { alert(); }"
      app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'application' %>"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          match '/posts', :to => "posts#index"
        end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
        end
      RUBY

      ENV["RAILS_ENV"] = "production"

      boot_rails
    end

    def teardown
      teardown_app
    end

    test "assets are concatenated when debug is off and allow_debugging is off either if debug_assets param is provided" do
      # config.assets.debug and config.assets.allow_debugging are false for production environment
      require "#{app_path}/config/environment"

      # the debug_assets params isn't used if allow_debugging is off
      get '/posts?debug_assets=true'
      assert_match %r{<script src="/assets/application-([0-z]+)\.js" type="text/javascript"></script>}, last_response.body
      assert_not_match %r{<script src="/assets/xmlhr-([0-z]+)\.js" type="text/javascript"></script>}, last_response.body
    end

    test "assets aren't concatened when allow_debugging is on and debug_assets params is true" do
      app_file "config/initializers/allow_debugging.rb", "Rails.application.config.assets.allow_debugging = true"

      require "#{app_path}/config/environment"

      get '/posts?debug_assets=true'
      assert_match %r{<script src="/assets/application-([0-z]+)\.js\?body=1" type="text/javascript"></script>}, last_response.body
      assert_match %r{<script src="/assets/xmlhr-([0-z]+)\.js\?body=1" type="text/javascript"></script>}, last_response.body
    end
  end
end
