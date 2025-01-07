# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "active_support/json"
require "propshaft"

module ApplicationTests
  class AssetsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(initializers: true)
    end

    def teardown
      teardown_app
    end

    def precompile!(env = nil)
      with_env env.to_h do
        quietly do
          rails ["assets:precompile", "--trace"]
        end
      end
    end

    def clean_assets!
      quietly do
        rails ["assets:clobber"]
      end
    end

    def assert_file_exists(filename)
      globbed = Dir[filename]
      assert Dir.exist?(File.dirname(filename)), "Directory #{File.dirname(filename)} does not exist"
      assert_predicate globbed, :one?, "Found #{globbed.size} files matching #{filename}. All files in the directory: #{Dir.entries(File.dirname(filename)).inspect}"
    end

    def assert_no_file_exists(filename)
      assert_not File.exist?(filename), "#{filename} does exist"
    end

    test "assets routes have higher priority" do
      app_file "app/assets/javascripts/demo-sha1_string.digested.js", "a = 1+1;"
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '*path', to: lambda { |env| [200, { "Content-Type" => "text/html" }, ["Not an asset"]] }
        end
      RUBY

      get "/assets/demo-sha1_string.digested.js"

      assert_equal "a = 1+1;", last_response.body.strip
    end

    test "precompile creates the file, gives it the original asset's content and run in production as default" do
      app_file "app/assets/javascripts/application.js", "alert();"
      app_file "app/assets/javascripts/foo/application.js", "alert();"

      precompile!

      files = Dir["#{app_path}/public/assets/application-*.js"]
      files << Dir["#{app_path}/public/assets/foo/application-*.js"].first
      files.each do |file|
        assert_not_nil file, "Expected application.js asset to be generated, but none found"
        assert_equal "alert();\n", File.read(file)
      end
    end

    def test_precompile_does_not_hit_the_database
      app_file "app/assets/javascripts/application.js", "alert();"
      app_file "app/assets/javascripts/foo/application.js", "alert();"
      app_file "app/controllers/users_controller.rb", <<-eoruby
        class UsersController < ApplicationController; end
      eoruby
      app_file "app/models/user.rb", <<-eoruby
        class User < ActiveRecord::Base; raise 'should not be reached'; end
      eoruby

      precompile! \
        RAILS_ENV: "production",
        DATABASE_URL: "postgresql://baduser:badpass@127.0.0.1/dbname"

      files = Dir["#{app_path}/public/assets/application-*.js"]
      files << Dir["#{app_path}/public/assets/foo/application-*.js"].first
      files.each do |file|
        assert_not_nil file, "Expected application.js asset to be generated, but none found"
        assert_equal "alert();".strip, File.read(file).strip
      end
    end

    test "precompile use assets defined in app env config" do
      add_to_env_config "production", 'config.assets.paths = [ "app/assets/javascripts" ]'
      app_file "app/assets/javascripts/something.js", "alert();"

      precompile! RAILS_ENV: "production"

      assert_file_exists("#{app_path}/public/assets/something-*.js")
    end

    test "propshaft cache is not shared between environments" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css", "body { background: url('rails.png'); }"
      add_to_env_config "production", 'config.assets.prefix = "production_assets"'

      precompile!

      assert_file_exists("#{app_path}/public/assets/application-*.css")

      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match(/assets\/rails-([0-z]+)\.png/, File.read(file))

      precompile! RAILS_ENV: "production"

      assert_file_exists("#{app_path}/public/production_assets/application-*.css")

      file = Dir["#{app_path}/public/production_assets/application-*.css"].first
      assert_match(/production_assets\/rails-([0-z]+)\.png/, File.read(file))
    end

    test "asset pipeline should use a Propshaft::Assembly" do
      add_to_config "config.action_controller.perform_caching = false"

      app "production"

      assert_equal Propshaft::Assembly, Rails.application.assets.class
    end

    test "precompile creates a manifest file with all the assets listed" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css", "body { background: url('rails.png'); }"

      precompile!

      manifest = Dir["#{app_path}/public/assets/.manifest.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert_match(/application-([0-z]+)\.css/, assets["application.css"])
      assert_match(/rails-([0-z]+)\.png/, assets["rails.png"])
    end

    test "the manifest file should be saved by default in the same assets folder" do
      app_file "app/assets/stylesheets/test.css", "a{color: red}"
      add_to_config "config.assets.prefix = '/x'"

      precompile!

      manifest = Dir["#{app_path}/public/x/.manifest.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert_match(/test-([0-z]+)\.css/, assets["test.css"])
    end

    test "assets do not require any assets group gem when manifest file is present" do
      app_file "app/assets/javascripts/application.js", "alert();"
      app_file "app/assets/config/manifest.js", "//= link application.js"

      precompile! RAILS_ENV: "production"

      manifest = Dir["#{app_path}/public/assets/.manifest.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      asset_path = assets["application.js"]

      # Load app env
      app "production"

      # Checking if Uglifier is defined we can know if Propshaft was reached or not
      assert_not defined?(Uglifier)
      get("/assets/#{asset_path}", {}, "HTTPS" => "on")
      assert_match "alert()", last_response.body
      assert_not defined?(Uglifier)
    end

    test "precompile properly refers files referenced with url" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css", "p { background-image: url('rails.png') }"

      precompile!

      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match(/\/assets\/rails-([0-z]+)\.png/, File.read(file))
    end

    test "precompile shouldn't use the digests present in manifest.json" do
      app_file "app/assets/images/rails.png", "notactuallyapng"

      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css", "p { background-image: url('rails.png') }"

      precompile! RAILS_ENV: "production"

      manifest = Dir["#{app_path}/public/assets/.manifest.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      asset_path = assets["application.css"]

      app_file "app/assets/images/rails.png", "p { url: change }"

      precompile!

      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert_not_equal asset_path, assets["application.css"]
    end

    test "precompile appends the SHA1 hash to files referenced with url and run in production" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css", "p { background-image: url('rails.png') }"

      precompile! RAILS_ENV: "production"

      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match(/\/assets\/rails-([0-z]+)\.png/, File.read(file))
    end

    test "precompile should handle utf8 filenames" do
      filename = "レイルズ.png"
      app_file "app/assets/images/#{filename}", "not an image really"

      precompile!

      manifest = Dir["#{app_path}/public/assets/.manifest.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert asset_path = assets.find { |(k, _)| /.png/.match?(k) }[1]

      # Load app env
      app "development"

      get "/assets/#{URI::RFC2396_PARSER.escape(asset_path)}"
      assert_match "not an image really", last_response.body
      assert_file_exists("#{app_path}/public/assets/#{asset_path}")
    end

    test "assets are cleaned up properly" do
      app_file "public/assets/application.js", "alert();"
      app_file "public/assets/application.css", "a { color: green; }"
      app_file "public/assets/subdir/broken.png", "not really an image file"

      clean_assets!

      files = Dir["#{app_path}/public/assets/**/*"]
      assert_equal 0, files.length, "Expected no assets, but found #{files.join(', ')}"
    end

    test "does not stream session cookies back" do
      app_file "app/assets/javascripts/demo-sha1_digest.digested.js", "alert();"

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/omg', :to => "omg#index"
        end
      RUBY

      class ::OmgController < ActionController::Base
        def index
          flash[:cool_story] = true
          render plain: "ok"
        end
      end

      get "/omg"
      assert_equal "ok", last_response.body

      get "/assets/demo-sha1_digest.digested.js"
      assert_match "alert()", last_response.body
      assert_nil last_response.headers["Set-Cookie"]
    end

    test "initialization on the assets group should set assets_dir" do
      require "#{app_path}/config/application"
      Rails.application.initialize!(:assets)
      assert_not_nil Rails.application.config.action_controller.assets_dir
    end

    test "enhancements to assets:precompile should only run once" do
      app_file "lib/tasks/enhance.rake", "Rake::Task['assets:precompile'].enhance { puts 'enhancement' }"
      output = precompile!
      assert_equal 1, output.scan("enhancement").size
    end

    test "digested assets are not mistakenly removed" do
      app_file "app/assets/application.css", "div { font-weight: bold }"

      precompile!

      files = Dir["#{app_path}/public/assets/application-*.css"]
      assert_equal 1, files.length, "Expected digested application.css asset to be generated, but none found"
    end

    test "digested assets are removed from configured path" do
      app_file "public/production_assets/application.js", "alert();"
      add_to_env_config "production", "config.assets.prefix = 'production_assets'"

      ENV["RAILS_ENV"] = nil

      clean_assets!

      files = Dir["#{app_path}/public/production_assets/application-*.js"]
      assert_equal 0, files.length, "Expected application.js asset to be removed, but still exists"
    end

    test "asset URLs should use the request's protocol by default" do
      app_with_assets_in_view
      add_to_config "config.asset_host = 'example.com'"

      class ::PostsController < ActionController::Base; end

      get "/posts", {}, { "HTTPS" => "off" }
      assert_match('src="http://example.com/assets/application-72d8340d.js', last_response.body)
      get "/posts", {}, { "HTTPS" => "on" }
      assert_match('src="https://example.com/assets/application-72d8340d.js', last_response.body)
    end

    private
      def app_with_assets_in_view
        app_file "app/assets/javascripts/application.js", "function f1() { alert(); }"
        app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'application' %>"

        app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/posts', :to => "posts#index"
        end
        RUBY
      end
  end
end
