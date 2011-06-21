require 'isolation/abstract_unit'
require 'active_support/core_ext/kernel/reporting'
require 'rack/test'

module ApplicationTests
  class AssetsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
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

    test "assets are compiled properly" do
      app_file "app/assets/javascripts/application.js", "alert();"

      capture(:stdout) do
        Dir.chdir(app_path){ `bundle exec rake assets:precompile` }
      end

      file = Dir["#{app_path}/public/assets/application-*.js"][0]
      assert_not_nil file, "Expected application.js asset to be generated, but none found"
      assert_equal "alert();\n", File.read(file)
    end

    test "assets are cleaned up properly" do
      app_file "public/assets/application.js", "alert();"
      app_file "public/assets/application.css", "a { color: green; }"
      app_file "public/assets/subdir/broken.png", "not really an image file"

      capture(:stdout) do
        Dir.chdir(app_path){ `bundle exec rake assets:clean` }
      end

      files = Dir["#{app_path}/public/assets/**/*"]
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
  end
end
