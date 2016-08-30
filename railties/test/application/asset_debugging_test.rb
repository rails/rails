require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class AssetDebuggingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      # FIXME: shush Sass warning spam, not relevant to testing Railties
      Kernel.silence_warnings do
        build_app(initializers: true)
      end

      app_file "app/assets/javascripts/application.js", "//= require_tree ."
      app_file "app/assets/javascripts/xmlhr.js", "function f1() { alert(); }"
      app_file "app/views/posts/index.html.erb", "<%= javascript_include_tag 'application' %>"

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/posts', to: "posts#index"
        end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
        end
      RUBY

      ENV["RAILS_ENV"] = "production"
    end

    def teardown
      teardown_app
    end

    # FIXME: shush Sass warning spam, not relevant to testing Railties
    def get(*)
      Kernel.silence_warnings { super }
    end

    test "assets are concatenated when debug is off and compile is off either if debug_assets param is provided" do
      # config.assets.debug and config.assets.compile are false for production environment
      ENV["RAILS_ENV"] = "production"
      output = Dir.chdir(app_path) { `bin/rails assets:precompile --trace 2>&1` }
      assert $?.success?, output

      # Load app env
      app "production"

      class ::PostsController < ActionController::Base ; end

      # the debug_assets params isn't used if compile is off
      get "/posts?debug_assets=true"
      assert_match(/<script src="\/assets\/application-([0-z]+)\.js"><\/script>/, last_response.body)
      assert_no_match(/<script src="\/assets\/xmlhr-([0-z]+)\.js"><\/script>/, last_response.body)
    end

    test "assets aren't concatenated when compile is true is on and debug_assets params is true" do
      add_to_env_config "production", "config.assets.compile = true"

      # Load app env
      app "production"

      class ::PostsController < ActionController::Base ; end

      get "/posts?debug_assets=true"
      assert_match(/<script src="\/assets\/application(\.self)?-([0-z]+)\.js\?body=1"><\/script>/, last_response.body)
      assert_match(/<script src="\/assets\/xmlhr(\.self)?-([0-z]+)\.js\?body=1"><\/script>/, last_response.body)
    end

    test "public path and tag methods are not over-written by the asset pipeline" do
      contents = "doesnotexist"
      cases = {
        asset_path:             %r{/#{ contents }},
        image_path:             %r{/images/#{ contents }},
        video_path:             %r{/videos/#{ contents }},
        audio_path:             %r{/audios/#{ contents }},
        font_path:              %r{/fonts/#{ contents }},
        javascript_path:        %r{/javascripts/#{ contents }},
        stylesheet_path:        %r{/stylesheets/#{ contents }},
        image_tag:              %r{<img src="/images/#{ contents }"},
        favicon_link_tag:       %r{<link rel="shortcut icon" type="image/x-icon" href="/images/#{ contents }" />},
        stylesheet_link_tag:    %r{<link rel="stylesheet" media="screen" href="/stylesheets/#{ contents }.css" />},
        javascript_include_tag: %r{<script src="/javascripts/#{ contents }.js">},
        audio_tag:              %r{<audio src="/audios/#{ contents }"></audio>},
        video_tag:              %r{<video src="/videos/#{ contents }"></video>}
      }

      cases.each do |(view_method, tag_match)|
        app_file "app/views/posts/index.html.erb", "<%= #{ view_method } '#{contents}', skip_pipeline: true %>"

        app "development"

        class ::PostsController < ActionController::Base ; end

        get "/posts?debug_assets=true"

        body = last_response.body
        assert_match(tag_match, body, "Expected `#{view_method}` to produce a match to #{ tag_match }, but did not: #{ body }")
      end
    end

    test "public url methods are not over-written by the asset pipeline" do
      contents = "doesnotexist"
      cases = {
        asset_url:       %r{http://example.org/#{ contents }},
        image_url:       %r{http://example.org/images/#{ contents }},
        video_url:       %r{http://example.org/videos/#{ contents }},
        audio_url:       %r{http://example.org/audios/#{ contents }},
        font_url:        %r{http://example.org/fonts/#{ contents }},
        javascript_url:  %r{http://example.org/javascripts/#{ contents }},
        stylesheet_url:  %r{http://example.org/stylesheets/#{ contents }},
      }

      cases.each do |(view_method, tag_match)|
        app_file "app/views/posts/index.html.erb", "<%= #{ view_method } '#{contents}', skip_pipeline: true %>"

        app "development"

        class ::PostsController < ActionController::Base ; end

        get "/posts?debug_assets=true"

        body = last_response.body
        assert_match(tag_match, body, "Expected `#{view_method}` to produce a match to #{ tag_match }, but did not: #{ body }")
      end
    end

    test "{ skip_pipeline: true } does not use the asset pipeline" do
      cases = {
        /\/assets\/application-.*.\.js/ => {},
        /application.js/                => { skip_pipeline: true },
      }
      cases.each do |(tag_match, options_hash)|
        app_file "app/views/posts/index.html.erb", "<%= asset_path('application.js', #{ options_hash }) %>"

        app "development"

        class ::PostsController < ActionController::Base ; end

        get "/posts?debug_assets=true"

        body = last_response.body.strip
        assert_match(tag_match, body, "Expected `asset_path` with `#{ options_hash}` to produce a match to #{ tag_match }, but did not: #{ body }")
      end
    end

    test "public_compute_asset_path does not use the asset pipeline" do
      cases = {
        compute_asset_path:        /\/assets\/application-.*.\.js/,
        public_compute_asset_path: /application.js/,
      }

      cases.each do |(view_method, tag_match)|
        app_file "app/views/posts/index.html.erb", "<%= #{ view_method } 'application.js' %>"

        app "development"

        class ::PostsController < ActionController::Base ; end

        get "/posts?debug_assets=true"

        body = last_response.body.strip
        assert_match(tag_match, body, "Expected `#{view_method}` to produce a match to #{ tag_match }, but did not: #{ body }")
      end
    end
  end
end
