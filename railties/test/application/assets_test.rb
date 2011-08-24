require 'isolation/abstract_unit'
require 'active_support/core_ext/kernel/reporting'
require 'rack/test'

module ApplicationTests
  class AssetsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(:initializers => true)
      boot_rails
    end

    def teardown
      teardown_app
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

    test "assets do not require compressors until it is used" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"
      ENV["RAILS_ENV"] = "production"
      require "#{app_path}/config/environment"

      assert !defined?(Uglifier)
      get "/assets/demo.js"
      assert_match "alert()", last_response.body
      assert defined?(Uglifier)
    end

    test "precompile creates the file, gives it the original asset's content and run in production as default" do
      app_file "app/assets/javascripts/application.js", "alert();"
      app_file "app/assets/javascripts/foo/application.js", "alert();"

      ENV["RAILS_ENV"] = nil
      capture(:stdout) do
        Dir.chdir(app_path){ `bundle exec rake assets:precompile` }
      end
      files = Dir["#{app_path}/public/assets/application-*.js"]
      files << Dir["#{app_path}/public/assets/foo/application-*.js"].first
      files.each do |file|
        assert_not_nil file, "Expected application.js asset to be generated, but none found"
        assert_equal "alert()", File.read(file)
      end
    end

    test "precompile appends the md5 hash to files referenced with asset_path and run in the provided RAILS_ENV" do
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"

      # capture(:stdout) do
        Dir.chdir(app_path){ `bundle exec rake assets:precompile RAILS_ENV=test` }
      # end
      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match /\/assets\/rails-([0-z]+)\.png/, File.read(file)
    end

    test "precompile appends the md5 hash to files referenced with asset_path and run in production as default even using RAILS_GROUPS=assets" do
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"

      ENV["RAILS_ENV"] = nil
      capture(:stdout) do
        Dir.chdir(app_path){ `bundle exec rake assets:precompile RAILS_GROUPS=assets` }
      end
      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match /\/assets\/rails-([0-z]+)\.png/, File.read(file)
    end

    test "assets are cleaned up properly" do
      app_file "public/assets/application.js", "alert();"
      app_file "public/assets/application.css", "a { color: green; }"
      app_file "public/assets/subdir/broken.png", "not really an image file"

      capture(:stdout) do
        Dir.chdir(app_path){ `bundle exec rake assets:clean` }
      end

      files = Dir["#{app_path}/public/assets/**/*", "#{app_path}/tmp/cache/*"]
      assert_equal 0, files.length, "Expected no assets, but found #{files.join(', ')}"
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

    test "files in any assets/ directories are not added to Sprockets" do
      %w[app lib vendor].each do |dir|
        app_file "#{dir}/assets/#{dir}_test.erb", "testing"
      end

      app_file "app/assets/javascripts/demo.js", "alert();"

      require "#{app_path}/config/environment"

      get "/assets/demo.js"
      assert_match "alert();", last_response.body
      assert_equal 200, last_response.status
    end

    test "assets are concatenated when debug is off and allow_debugging is off either if debug_assets param is provided" do
      app_with_assets_in_view

      # config.assets.debug and config.assets.allow_debugging are false for production environment
      ENV["RAILS_ENV"] = "production"
      require "#{app_path}/config/environment"

      class ::PostsController < ActionController::Base ; end

      # the debug_assets params isn't used if allow_debugging is off
      get '/posts?debug_assets=true'
      assert_match /<script src="\/assets\/application-([0-z]+)\.js" type="text\/javascript"><\/script>/, last_response.body
      assert_not_match /<script src="\/assets\/xmlhr-([0-z]+)\.js" type="text\/javascript"><\/script>/, last_response.body
    end

    test "assets aren't concatened when allow_debugging is on and debug_assets params is true" do
      app_with_assets_in_view
      app_file "config/initializers/allow_debugging.rb", "Rails.application.config.assets.allow_debugging = true"

      ENV["RAILS_ENV"] = "production"
      require "#{app_path}/config/environment"

      class ::PostsController < ActionController::Base ; end

      get '/posts?debug_assets=true'
      assert_match /<script src="\/assets\/application-([0-z]+)\.js\?body=1" type="text\/javascript"><\/script>/, last_response.body
      assert_match /<script src="\/assets\/xmlhr-([0-z]+)\.js\?body=1" type="text\/javascript"><\/script>/, last_response.body
    end

    private
    def app_with_assets_in_view
      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js", "function f1() { alert(); }"
      app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'application' %>"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          match '/posts', :to => "posts#index"
        end
      RUBY
    end
  end
end
