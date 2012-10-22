require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class AssetDebuggingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(initializers: true)

      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js", "function f1() { alert(); }"
      app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'application' %>"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          get '/posts', to: "posts#index"
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

    test "assets are concatenated when debug is off and compile is off either if debug_assets param is provided" do
      # config.assets.debug and config.assets.compile are false for production environment
      ENV["RAILS_ENV"] = "production"
      output = Dir.chdir(app_path){ `bundle exec rake assets:precompile --trace 2>&1` }
      assert $?.success?, output
      require "#{app_path}/config/environment"

      class ::PostsController < ActionController::Base ; end

      # the debug_assets params isn't used if compile is off
      get '/posts?debug_assets=true'
      assert_match(/<script src="\/assets\/application-([0-z]+)\.js"><\/script>/, last_response.body)
      assert_no_match(/<script src="\/assets\/xmlhr-([0-z]+)\.js"><\/script>/, last_response.body)
    end

    test "assets aren't concatened when compile is true is on and debug_assets params is true" do
      add_to_env_config "production", "config.assets.compile = true"

      ENV["RAILS_ENV"] = "production"
      require "#{app_path}/config/environment"

      class ::PostsController < ActionController::Base ; end

      get '/posts?debug_assets=true'
      assert_match(/<script src="\/assets\/application-([0-z]+)\.js\?body=1"><\/script>/, last_response.body)
      assert_match(/<script src="\/assets\/xmlhr-([0-z]+)\.js\?body=1"><\/script>/, last_response.body)
    end
  end
end
