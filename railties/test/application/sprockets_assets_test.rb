# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "active_support/json"
require "sprockets"

module ApplicationTests
  class SprocketsAssetsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def tmp_path(*args)
      @sprockets_tmp_path ||= File.realpath(Dir.mktmpdir(nil, File.join(RAILS_FRAMEWORK_ROOT, "tmp")))
      File.join(@sprockets_tmp_path, *args)
    end

    def setup
      build_app(initializers: true)

      contents = File.read("#{app_path}/config/application.rb")
      contents.gsub!(/propshaft/, "sprockets/railtie")
      File.write("#{app_path}/config/application.rb", contents)

      contents = File.read("#{app_path}/Gemfile")
      contents.gsub!(/propshaft/, "sprockets-rails")
      File.write("#{app_path}/Gemfile", contents)

      remove_from_env_config :development, "config.assets.digest = false"

      app_file "app/assets/config/manifest.js", <<~JS
        //= link_tree ../images
        //= link_directory ../stylesheets .css
      JS
      assert_file_exists("#{app_path}/app/assets/config/manifest.js")

      add_to_env_config :production, "config.assets.compile = false"
      add_to_env_config :development, "config.assets.quiet = true"
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

    def run_app_update
      quietly do
        rails ["app:update"]
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
      app_file "app/assets/images/rails.png", "notactuallyapng"
      app_file "app/assets/javascripts/demo.js.erb", "a = <%= image_path('rails.png').inspect %>;"

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '*path', to: lambda { |env| [200, { "Content-Type" => "text/html" }, ["Not an asset"]] }
        end
      RUBY

      add_to_env_config "development", "config.assets.digest = false"

      require "#{app_path}/config/environment"

      get "/assets/demo.js"
      assert_equal 'a = "/assets/rails.png";', last_response.body.strip
    end

    test "precompile creates the file, gives it the original asset's content and run in production as default" do
      app_file "app/assets/config/manifest.js", "//= link_tree ../javascripts"
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
      app_file "app/assets/config/manifest.js", "//= link_tree ../javascripts"
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

    test "precompile application.js and application.css and all other non JS/CSS files if manifest requests" do
      app_file "app/assets/javascripts/application.js", "alert();"
      app_file "app/assets/stylesheets/application.css", "body{}"

      app_file "app/assets/javascripts/someapplication.js", "alert();"
      app_file "app/assets/stylesheets/someapplication.css", "body{}"

      app_file "app/assets/javascripts/something.min.js", "alert();"
      app_file "app/assets/stylesheets/something.min.css", "body{}"

      app_file "app/assets/javascripts/something.else.js.erb", "alert();"
      app_file "app/assets/stylesheets/something.else.css.erb", "body{}"

      app_file "app/assets/config/manifest.js", <<~JS
        //= link_tree ../images
        //= link_directory ../stylesheets .css
        //= link_directory ../javascripts .js
      JS

      images_should_compile = ["a.png", "happyface.png", "happy_face.png", "happy.face.png",
                               "happy-face.png", "happy.happy_face.png", "happy_happy.face.png",
                               "happy.happy.face.png", "-happy.png", "-happy.face.png",
                               "_happy.face.png", "_happy.png"]

      images_should_compile.each do |filename|
        app_file "app/assets/images/#{filename}", "happy"
      end

      precompile!

      images_should_compile = ["a-*.png", "happyface-*.png", "happy_face-*.png", "happy.face-*.png",
                               "happy-face-*.png", "happy.happy_face-*.png", "happy_happy.face-*.png",
                               "happy.happy.face-*.png", "-happy-*.png", "-happy.face-*.png",
                               "_happy.face-*.png", "_happy-*.png"]

      images_should_compile.each do |filename|
        assert_file_exists("#{app_path}/public/assets/#{filename}")
      end

      assert_file_exists("#{app_path}/public/assets/application-*.js")
      assert_file_exists("#{app_path}/public/assets/application-*.css")

      assert_no_file_exists("#{app_path}/public/assets/someapplication-*.js")
      assert_no_file_exists("#{app_path}/public/assets/someapplication-*.css")

      assert_no_file_exists("#{app_path}/public/assets/something.min-*.js")
      assert_no_file_exists("#{app_path}/public/assets/something.min-*.css")

      assert_no_file_exists("#{app_path}/public/assets/something.else-*.js")
      assert_no_file_exists("#{app_path}/public/assets/something.else-*.css")
    end

    test "precompile something.js for directory containing index file" do
      add_to_config "config.assets.precompile = [ 'something.js' ]"
      app_file "app/assets/javascripts/something/index.js.erb", "alert();"

      precompile!

      assert_file_exists("#{app_path}/public/assets/something-*.js")
    end

    test "precompile use assets defined in app env config" do
      add_to_env_config "production", 'config.assets.precompile = [ "something.js" ]'
      app_file "app/assets/javascripts/something.js.erb", "alert();"

      precompile! RAILS_ENV: "production"

      assert_file_exists("#{app_path}/public/assets/something-*.js")
    end

    test "sprockets cache is not shared between environments" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css.erb", "body { background: '<%= asset_path('rails.png') %>'; }"
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

    test "precompile use assets defined in app config and reassigned in app env config" do
      add_to_config 'config.assets.precompile = [ "something_manifest.js" ]'
      add_to_env_config "production", 'config.assets.precompile += [ "another_manifest.js" ]'

      app_file "app/assets/config/something_manifest.js", "//= link something.js"
      app_file "app/assets/config/another_manifest.js", "//= link another.js"

      app_file "app/assets/javascripts/something.js.erb", "alert();"
      app_file "app/assets/javascripts/another.js.erb", "alert();"

      precompile! RAILS_ENV: "production"

      assert_file_exists("#{app_path}/public/assets/something_manifest-*.js")
      assert_file_exists("#{app_path}/public/assets/something-*.js")
      assert_file_exists("#{app_path}/public/assets/another_manifest-*.js")
      assert_file_exists("#{app_path}/public/assets/another-*.js")
    end

    test "asset pipeline should use a Sprockets::CachedEnvironment when config.assets.digest is true" do
      add_to_config "config.action_controller.perform_caching = false"
      add_to_env_config "production", "config.assets.compile = true"

      # Load app env
      app "production"

      assert_equal Sprockets::CachedEnvironment, Rails.application.assets.class
    end

    test "precompile creates a manifest file with all the assets listed" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"

      precompile!

      manifest = Dir["#{app_path}/public/assets/.sprockets-manifest-*.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert_match(/application-([0-z]+)\.css/, assets["assets"]["application.css"])
      assert_match(/rails-([0-z]+)\.png/, assets["assets"]["rails.png"])
    end

    test "the manifest file should be saved by default in the same assets folder" do
      app_file "app/assets/stylesheets/test.css", "a{color: red}"
      add_to_config "config.assets.prefix = '/x'"

      precompile!

      manifest = Dir["#{app_path}/public/x/.sprockets-manifest-*.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert_match(/test-([0-z]+)\.css/, assets["assets"]["test.css"])
    end

    test "assets do not require any assets group gem when manifest file is present" do
      app_file "app/assets/javascripts/application.js", "alert();"
      app_file "app/assets/config/manifest.js", "//= link application.js"

      precompile! RAILS_ENV: "production"

      manifest = Dir["#{app_path}/public/assets/.sprockets-manifest-*.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      asset_path = assets["assets"]["application.js"]

      # Load app env
      app "production"

      # Checking if Uglifier is defined we can know if Sprockets was reached or not
      assert_not defined?(Uglifier)
      get("/assets/#{asset_path}", {}, "HTTPS" => "on")
      assert_match "alert()", last_response.body
      assert_not defined?(Uglifier)
    end

    test "precompile properly refers files referenced with asset_path" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css.erb", "p { background-image: url(<%= asset_path('rails.png') %>) }"

      precompile!

      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match(/\/assets\/rails-([0-z]+)\.png/, File.read(file))
    end

    test "precompile shouldn't use the digests present in manifest.json" do
      app_file "app/assets/images/rails.png", "notactuallyapng"

      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css.erb", "p { background-image: url(<%= asset_path('rails.png') %>) }"

      precompile! RAILS_ENV: "production"

      manifest = Dir["#{app_path}/public/assets/.sprockets-manifest-*.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      asset_path = assets["assets"]["application.css"]

      app_file "app/assets/images/rails.png", "p { url: change }"

      precompile!

      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert_not_equal asset_path, assets["assets"]["application.css"]
    end

    test "precompile appends the MD5 hash to files referenced with asset_path and run in production with digest true" do
      app_file "app/assets/images/rails.png", "notactuallyapng"
      remove_file "app/assets/stylesheets/application.css"
      app_file "app/assets/stylesheets/application.css.erb", "p { background-image: url(<%= asset_path('rails.png') %>) }"

      precompile! RAILS_ENV: "production"

      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match(/\/assets\/rails-([0-z]+)\.png/, File.read(file))
    end

    test "precompile should handle utf8 filenames" do
      filename = "レイルズ.png"
      app_file "app/assets/images/#{filename}", "not an image really"
      app_file "app/assets/config/manifest.js", "//= link_tree ../images"
      add_to_config "config.assets.precompile = %w(manifest.js)"

      precompile!

      manifest = Dir["#{app_path}/public/assets/.sprockets-manifest-*.json"].first
      assets = ActiveSupport::JSON.decode(File.read(manifest))
      assert asset_path = assets["assets"].find { |(k, _)| /.png/.match?(k) }[1]

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

    test "assets routes are not drawn when compilation is disabled" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"
      add_to_config "config.assets.compile = false"

      # Load app env
      app "production"

      get("/assets/demo.js", {}, "HTTPS" => "on")
      assert_equal 404, last_response.status
    end

    test "does not stream session cookies back" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/omg', :to => "omg#index"
        end
      RUBY

      add_to_env_config "development", "config.assets.digest = false"

      # Load app env
      app "development"

      class ::OmgController < ActionController::Base
        def index
          flash[:cool_story] = true
          render plain: "ok"
        end
      end

      get "/omg"
      assert_equal "ok", last_response.body

      get "/assets/demo.js"
      assert_match "alert()", last_response.body
      assert_nil last_response.headers["Set-Cookie"]
    end

    test "files in any assets/ directories are not added to Sprockets" do
      %w[app lib vendor].each do |dir|
        app_file "#{dir}/assets/#{dir}_test.erb", "testing"
      end

      app_file "app/assets/javascripts/demo.js", "alert();"

      add_to_env_config "development", "config.assets.digest = false"

      # Load app env
      app "development"

      get "/assets/demo.js"
      assert_match "alert();", last_response.body
      assert_equal 200, last_response.status
    end

    test "assets are concatenated when debug is off and compile is off either if debug_assets param is provided" do
      app_with_assets_in_view

      # config.assets.debug and config.assets.compile are false for production environment
      precompile! RAILS_ENV: "production"

      # Load app env
      app "production"

      class ::PostsController < ActionController::Base ; end

      # the debug_assets params isn't used if compile is off
      get("/posts?debug_assets=true", {}, "HTTPS" => "on")
      assert_match(/<script src="\/assets\/application-([0-z]+)\.js"><\/script>/, last_response.body)
      assert_no_match(/<script src="\/assets\/xmlhr-([0-z]+)\.js"><\/script>/, last_response.body)
    end

    test "assets can access model information when precompiling" do
      app_file "app/models/post.rb", "class Post; end"
      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js.erb", "<%= Post.name %>"
      app_file "app/assets/config/manifest.js", "//= link application.js"

      precompile!

      assert_file_exists("#{app_path}/public/assets/application-*.js")
      assert_match(/Post;/, File.read(Dir["#{app_path}/public/assets/application-*.js"].first))
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
      add_to_config "config.assets.compile = true"

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
      add_to_env_config "development", "config.assets.digest = false"

      # Load app env
      app "development"

      class ::PostsController < ActionController::Base; end

      get "/posts", {}, { "HTTPS" => "off" }
      assert_match('src="http://example.com/assets/application.js', last_response.body)
      get "/posts", {}, { "HTTPS" => "on" }
      assert_match('src="https://example.com/assets/application.js', last_response.body)
    end

    test "asset URLs should be protocol-relative if no request is in scope" do
      app_file "app/assets/images/rails.png", "notreallyapng"
      app_file "app/assets/javascripts/image_loader.js.erb", "var src='<%= image_path('rails.png') %>';"
      add_to_config "config.assets.precompile = %w{rails.png image_loader.js}"
      add_to_config "config.asset_host = 'example.com'"
      add_to_env_config "development", "config.assets.digest = false"

      precompile!

      assert_match "src='//example.com/assets/rails.png'", File.read(Dir["#{app_path}/public/assets/image_loader-*.js"].first)
    end

    test "asset paths should use RAILS_RELATIVE_URL_ROOT by default" do
      ENV["RAILS_RELATIVE_URL_ROOT"] = "/sub/uri"
      app_file "app/assets/images/rails.png", "notreallyapng"
      app_file "app/assets/javascripts/app.js.erb", "var src='<%= image_path('rails.png') %>';"
      add_to_config "config.assets.precompile = %w{rails.png app.js}"
      add_to_env_config "development", "config.assets.digest = false"

      precompile!

      assert_match "src='/sub/uri/assets/rails.png'", File.read(Dir["#{app_path}/public/assets/app-*.js"].first)
    end

    test "app:update removes_sprockets" do
      config = "#{app_path}/config/environments/production.rb"
      assert_changes -> { File.readlines(config).grep(/config\.assets/) }, from: ["config.assets.compile = false\n"], to: [] do
        run_app_update
      end
    end

    test "plugin serving sprockets assets" do
      @plugin = make_plugin
      @plugin.write "app/assets/javascripts/engine.js.erb", "<%= :alert %>();"
      add_to_env_config "development", "config.assets.digest = false"

      require "#{app_path}/config/environment"

      get "/assets/engine.js"
      assert_match "alert()", last_response.body
    end

    test "setting priority for engines with config.railties_order" do
      @plugin = make_plugin

      @blog = engine "blog" do |plugin|
        plugin.write "lib/blog.rb", <<-RUBY
          module Blog
            class Engine < ::Rails::Engine
            end
          end
        RUBY
      end

      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY
      controller "main", <<-RUBY
        class MainController < ActionController::Base
          def foo
            render inline: '<%= render partial: "application/foo" %>'
          end
          def bar
            render inline: '<%= render partial: "application/bar" %>'
          end
        end
      RUBY
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "/foo" => "main#foo"
          get "/bar" => "main#bar"
        end
      RUBY
      @plugin.write "app/views/application/_foo.html.erb", <<-RUBY
        Bukkit's foo partial
      RUBY
      app_file "app/views/application/_foo.html.erb", <<-RUBY
        App's foo partial
      RUBY
      @blog.write "app/views/application/_bar.html.erb", <<-RUBY
        Blog's bar partial
      RUBY
      app_file "app/views/application/_bar.html.erb", <<-RUBY
        App's bar partial
      RUBY
      @plugin.write "app/assets/javascripts/foo.js", <<-RUBY
        // Bukkit's foo js
      RUBY
      app_file "app/assets/javascripts/foo.js", <<-RUBY
        // App's foo js
      RUBY
      @blog.write "app/assets/javascripts/bar.js", <<-RUBY
        // Blog's bar js
      RUBY
      app_file "app/assets/javascripts/bar.js", <<-RUBY
        // App's bar js
      RUBY
      add_to_config("config.railties_order = [:all, :main_app, Blog::Engine]")
      add_to_env_config "development", "config.assets.digest = false"

      require "#{app_path}/config/environment"

      get("/foo")
      assert_equal "Bukkit's foo partial", last_response.body.strip
      get("/bar")
      assert_equal "App's bar partial", last_response.body.strip

      get("/assets/foo.js")
      assert_match "// Bukkit's foo js", last_response.body.strip

      get("/assets/bar.js")
      assert_match "// App's bar js", last_response.body.strip
    end

    private
      def app_with_assets_in_view
        app_file "app/assets/javascripts/application.js", "//= require_tree ."
        app_file "app/assets/javascripts/xmlhr.js", "function f1() { alert(); }"
        app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'application' %>"
        app_file "app/assets/config/manifest.js", <<~JS
          //= link_tree ../images
          //= link_directory ../stylesheets .css
          //= link_directory ../javascripts .js
        JS

        app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/posts', :to => "posts#index"
        end
        RUBY
      end

      def make_plugin
        engine "bukkits" do |plugin|
          plugin.write "lib/bukkits.rb", <<-RUBY
            module Bukkits
              class Engine < ::Rails::Engine
                railtie_name "bukkits"
              end
            end
          RUBY

          plugin.write "lib/another.rb", "class Another; end"
        end
      end
  end
end
