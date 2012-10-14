# -*- coding: utf-8 -*-
require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class AssetsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(initializers: true)
      boot_rails
    end

    def teardown
      teardown_app
    end

    def precompile!(env = nil)
      quietly do
        precompile_task = "bundle exec rake assets:precompile #{env} --trace 2>&1"
        output = Dir.chdir(app_path) { %x[ #{precompile_task} ] }
        assert $?.success?, output
        output
      end
    end

    def clean_assets!
      quietly do
        assert Dir.chdir(app_path) { system('bundle exec rake assets:clean') }
      end
    end

    def assert_file_exists(filename)
      assert File.exists?(filename), "missing #{filename}"
    end

    def assert_no_file_exists(filename)
      assert !File.exists?(filename), "#{filename} does exist"
    end

    test "assets routes have higher priority" do
      app_file "app/assets/javascripts/demo.js.erb", "a = <%= image_path('rails.png').inspect %>;"

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get '*path', to: lambda { |env| [200, { "Content-Type" => "text/html" }, "Not an asset"] }
        end
      RUBY

      require "#{app_path}/config/environment"

      get "/assets/demo.js"
      assert_equal 'a = "/assets/rails.png";', last_response.body.strip
    end

    test "assets do not require compressors until it is used" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"
      add_to_env_config "production", "config.assets.compile = true"

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
      precompile!

      files = Dir["#{app_path}/public/assets/application-*.js"]
      files << Dir["#{app_path}/public/assets/application.js"].first
      files << Dir["#{app_path}/public/assets/foo/application-*.js"].first
      files << Dir["#{app_path}/public/assets/foo/application.js"].first
      files.each do |file|
        assert_not_nil file, "Expected application.js asset to be generated, but none found"
        assert_equal "alert();", File.read(file)
      end
    end

    test "precompile application.js and application.css and all other non JS/CSS files" do
      app_file "app/assets/javascripts/application.js", "alert();"
      app_file "app/assets/stylesheets/application.css", "body{}"

      app_file "app/assets/javascripts/someapplication.js", "alert();"
      app_file "app/assets/stylesheets/someapplication.css", "body{}"

      app_file "app/assets/javascripts/something.min.js", "alert();"
      app_file "app/assets/stylesheets/something.min.css", "body{}"

      app_file "app/assets/javascripts/something.else.js.erb", "alert();"
      app_file "app/assets/stylesheets/something.else.css.erb", "body{}"

      images_should_compile = ["a.png", "happyface.png", "happy_face.png", "happy.face.png",
                               "happy-face.png", "happy.happy_face.png", "happy_happy.face.png",
                               "happy.happy.face.png", "-happy.png", "-happy.face.png",
                               "_happy.face.png", "_happy.png"]

      images_should_compile.each do |filename|
        app_file "app/assets/images/#{filename}", "happy"
      end

      precompile!

      images_should_compile.each do |filename|
        assert_file_exists("#{app_path}/public/assets/#{filename}")
      end

      assert_file_exists("#{app_path}/public/assets/application.js")
      assert_file_exists("#{app_path}/public/assets/application.css")

      assert_no_file_exists("#{app_path}/public/assets/someapplication.js")
      assert_no_file_exists("#{app_path}/public/assets/someapplication.css")

      assert_no_file_exists("#{app_path}/public/assets/something.min.js")
      assert_no_file_exists("#{app_path}/public/assets/something.min.css")

      assert_no_file_exists("#{app_path}/public/assets/something.else.js")
      assert_no_file_exists("#{app_path}/public/assets/something.else.css")
    end

    test "precompile something.js for directory containing index file" do
      add_to_config "config.assets.precompile = [ 'something.js' ]"
      app_file "app/assets/javascripts/something/index.js.erb", "alert();"

      precompile!

      assert_file_exists("#{app_path}/public/assets/something.js")
    end

    test "asset pipeline should use a Sprockets::Index when config.assets.digest is true" do
      add_to_config "config.assets.digest = true"
      add_to_config "config.action_controller.perform_caching = false"

      ENV["RAILS_ENV"] = "production"
      require "#{app_path}/config/environment"

      assert_equal Sprockets::Index, Rails.application.assets.class
    end

    test "precompile creates a manifest file with all the assets listed" do
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"
      app_file "app/assets/javascripts/application.js", "alert();"
      # digest is default in false, we must enable it for test environment
      add_to_config "config.assets.digest = true"

      precompile!
      manifest = "#{app_path}/public/assets/manifest.yml"

      assets = YAML.load_file(manifest)
      assert_match(/application-([0-z]+)\.js/, assets["application.js"])
      assert_match(/application-([0-z]+)\.css/, assets["application.css"])
    end

    test "the manifest file should be saved by default in the same assets folder" do
      app_file "app/assets/javascripts/application.js", "alert();"
      # digest is default in false, we must enable it for test environment
      add_to_config "config.assets.digest = true"
      add_to_config "config.assets.prefix = '/x'"

      precompile!

      manifest = "#{app_path}/public/x/manifest.yml"
      assets = YAML.load_file(manifest)
      assert_match(/application-([0-z]+)\.js/, assets["application.js"])
    end

    test "precompile does not append asset digests when config.assets.digest is false" do
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"
      app_file "app/assets/javascripts/application.js", "alert();"
      add_to_config "config.assets.digest = false"

      precompile!

      assert_file_exists("#{app_path}/public/assets/application.js")
      assert_file_exists("#{app_path}/public/assets/application.css")

      manifest = "#{app_path}/public/assets/manifest.yml"

      assets = YAML.load_file(manifest)
      assert_equal "application.js", assets["application.js"]
      assert_equal "application.css", assets["application.css"]
    end

    test "assets do not require any assets group gem when manifest file is present" do
      app_file "app/assets/javascripts/application.js", "alert();"
      add_to_env_config "production", "config.serve_static_assets = true"

      ENV["RAILS_ENV"] = "production"
      precompile!

      manifest = "#{app_path}/public/assets/manifest.yml"
      assets = YAML.load_file(manifest)
      asset_path = assets["application.js"]

      require "#{app_path}/config/environment"

      # Checking if Uglifier is defined we can know if Sprockets was reached or not
      assert !defined?(Uglifier)
      get "/assets/#{asset_path}"
      assert_match "alert()", last_response.body
      assert !defined?(Uglifier)
    end

    test "assets raise AssetNotPrecompiledError when manifest file is present and requested file isn't precompiled" do
      app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'app' %>"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          get '/posts', :to => "posts#index"
        end
      RUBY

      ENV["RAILS_ENV"] = "production"
      precompile!

      # Create file after of precompile
      app_file "app/assets/javascripts/app.js", "alert();"

      require "#{app_path}/config/environment"
      class ::PostsController < ActionController::Base
        def show_detailed_exceptions?() true end
      end

      get '/posts'
      assert_match(/AssetNotPrecompiledError/, last_response.body)
      assert_match(/app\.js isn&#39;t precompiled/, last_response.body)
    end

    test "assets raise AssetNotPrecompiledError when manifest file is present and requested file isn't precompiled if digest is disabled" do
      app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'app' %>"
      add_to_config "config.assets.compile = false"
      add_to_config "config.assets.digest = false"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          get '/posts', :to => "posts#index"
        end
      RUBY

      ENV["RAILS_ENV"] = "production"
      precompile!

      # Create file after of precompile
      app_file "app/assets/javascripts/app.js", "alert();"

      require "#{app_path}/config/environment"
      class ::PostsController < ActionController::Base
        def show_detailed_exceptions?() true end
      end

      get '/posts'
      assert_match(/AssetNotPrecompiledError/, last_response.body)
      assert_match(/app\.js isn&#39;t precompiled/, last_response.body)
    end

    test "precompile properly refers files referenced with asset_path and and run in the provided RAILS_ENV" do
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"
      # digest is default in false, we must enable it for test environment
      add_to_env_config "test", "config.assets.digest = true"

      precompile!('RAILS_ENV=test')

      file = Dir["#{app_path}/public/assets/application.css"].first
      assert_match(/\/assets\/rails\.png/, File.read(file))
      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match(/\/assets\/rails-([0-z]+)\.png/, File.read(file))
    end

    test "precompile shouldn't use the digests present in manifest.yml" do
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"

      ENV["RAILS_ENV"] = "production"
      precompile!

      manifest = "#{app_path}/public/assets/manifest.yml"
      assets = YAML.load_file(manifest)
      asset_path = assets["application.css"]

      app_file "app/assets/images/rails.png", "image changed"

      precompile!
      assets = YAML.load_file(manifest)

      assert_not_equal asset_path, assets["application.css"]
    end

    test "precompile appends the md5 hash to files referenced with asset_path and run in production as default even using RAILS_GROUPS=assets" do
      app_file "app/assets/stylesheets/application.css.erb", "<%= asset_path('rails.png') %>"
      add_to_config "config.assets.compile = true"

      ENV["RAILS_ENV"] = nil

      precompile!('RAILS_GROUPS=assets')

      file = Dir["#{app_path}/public/assets/application-*.css"].first
      assert_match(/\/assets\/rails-([0-z]+)\.png/, File.read(file))
    end

    test "precompile should handle utf8 filenames" do
      filename = "レイルズ.png"
      app_file "app/assets/images/#{filename}", "not a image really"
      add_to_config "config.assets.precompile = [ /\.png$/, /application.(css|js)$/ ]"

      precompile!
      require "#{app_path}/config/environment"

      get "/assets/#{URI.parser.escape(filename)}"
      assert_match "not a image really", last_response.body
      assert_file_exists("#{app_path}/public/assets/#{filename}")
    end

    test "assets are cleaned up properly" do
      app_file "public/assets/application.js", "alert();"
      app_file "public/assets/application.css", "a { color: green; }"
      app_file "public/assets/subdir/broken.png", "not really an image file"

      clean_assets!

      files = Dir["#{app_path}/public/assets/**/*", "#{app_path}/tmp/cache/assets/development/*",
                  "#{app_path}/tmp/cache/assets/test/*", "#{app_path}/tmp/cache/assets/production/*"]
      assert_equal 0, files.length, "Expected no assets, but found #{files.join(', ')}"
    end

    test "assets routes are not drawn when compilation is disabled" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"
      add_to_config "config.assets.compile = false"

      ENV["RAILS_ENV"] = "production"
      require "#{app_path}/config/environment"

      get "/assets/demo.js"
      assert_equal 404, last_response.status
    end

    test "does not stream session cookies back" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          get '/omg', :to => "omg#index"
        end
      RUBY

      require "#{app_path}/config/environment"

      class ::OmgController < ActionController::Base
        def index
          flash[:cool_story] = true
          render text: "ok"
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

    test "assets are concatenated when debug is off and compile is off either if debug_assets param is provided" do
      app_with_assets_in_view

      # config.assets.debug and config.assets.compile are false for production environment
      ENV["RAILS_ENV"] = "production"
      precompile!

      require "#{app_path}/config/environment"

      class ::PostsController < ActionController::Base ; end

      # the debug_assets params isn't used if compile is off
      get '/posts?debug_assets=true'
      assert_match(/<script src="\/assets\/application-([0-z]+)\.js"><\/script>/, last_response.body)
      assert_no_match(/<script src="\/assets\/xmlhr-([0-z]+)\.js"><\/script>/, last_response.body)
    end

    test "assets can access model information when precompiling" do
      app_file "app/models/post.rb", "class Post; end"
      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js.erb", "<%= Post.name %>"

      add_to_config "config.assets.digest = false"
      precompile!
      assert_equal "Post;\n", File.read("#{app_path}/public/assets/application.js")
    end

    test "assets can't access model information when precompiling if not initializing the app" do
      app_file "app/models/post.rb", "class Post; end"
      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js.erb", "<%= defined?(Post) || :NoPost %>"

      add_to_config "config.assets.digest = false"
      add_to_config "config.assets.initialize_on_precompile = false"

      precompile!
      assert_equal "NoPost;\n", File.read("#{app_path}/public/assets/application.js")
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
      app_file "app/assets/application.js", "alert();"
      add_to_config "config.assets.compile = true"
      add_to_config "config.assets.digest = true"

      precompile!

      files = Dir["#{app_path}/public/assets/application-*.js"]
      assert_equal 1, files.length, "Expected digested application.js asset to be generated, but none found"
    end

    test "digested assets are removed from configured path" do
      app_file "public/production_assets/application.js", "alert();"
      add_to_env_config "production", "config.assets.prefix = 'production_assets'"

      ENV["RAILS_ENV"] = nil

      clean_assets!

      files = Dir["#{app_path}/public/production_assets/application.js"]
      assert_equal 0, files.length, "Expected application.js asset to be removed, but still exists"
    end

    test "asset urls should use the request's protocol by default" do
      app_with_assets_in_view
      add_to_config "config.asset_host = 'example.com'"
      require "#{app_path}/config/environment"
      class ::PostsController < ActionController::Base; end

      get '/posts', {}, {'HTTPS'=>'off'}
      assert_match('src="http://example.com/assets/application.js', last_response.body)
      get '/posts', {}, {'HTTPS'=>'on'}
      assert_match('src="https://example.com/assets/application.js', last_response.body)
    end

    test "asset urls should be protocol-relative if no request is in scope" do
      app_file "app/assets/javascripts/image_loader.js.erb", 'var src="<%= image_path("rails.png") %>";'
      add_to_config "config.assets.precompile = %w{image_loader.js}"
      add_to_config "config.asset_host = 'example.com'"
      precompile!

      assert_match 'src="//example.com/assets/rails.png"', File.read("#{app_path}/public/assets/image_loader.js")
    end

    test "asset paths should use RAILS_RELATIVE_URL_ROOT by default" do
      ENV["RAILS_RELATIVE_URL_ROOT"] = "/sub/uri"

      app_file "app/assets/javascripts/app.js.erb", 'var src="<%= image_path("rails.png") %>";'
      add_to_config "config.assets.precompile = %w{app.js}"
      precompile!

      assert_match 'src="/sub/uri/assets/rails.png"', File.read("#{app_path}/public/assets/app.js")
    end

    test "html assets are compiled when executing precompile" do
      app_file "app/assets/pages/page.html.erb", "<%= javascript_include_tag :application %>"
      ENV["RAILS_ENV"]   = "production"
      ENV["RAILS_GROUP"] = "assets"

      quietly do
        Dir.chdir(app_path){ `bundle exec rake assets:precompile` }
      end

      assert_file_exists("#{app_path}/public/assets/page.html")
    end

    test "assets:cache:clean should clean cache" do
      ENV["RAILS_ENV"] = "production"
      precompile!

      quietly do
        Dir.chdir(app_path){ `bundle exec rake assets:cache:clean` }
      end

      require "#{app_path}/config/environment"
      assert_equal 0, Dir.entries(Rails.application.assets.cache.cache_path).size - 2 # reject [".", ".."]
    end

    private

    def app_with_assets_in_view
      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js", "function f1() { alert(); }"
      app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'application' %>"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          get '/posts', :to => "posts#index"
        end
      RUBY
    end
  end
end
