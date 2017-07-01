require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class MiddlewareStaticTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    # Regression test to #8907
    # See https://github.com/rails/rails/commit/9cc82b77196d21a5c7021f6dca59ab9b2b158a45#commitcomment-2416514
    test "doesn't set Cache-Control header when it is nil" do
      app_file "public/foo.html", "static"

      require "#{app_path}/config/environment"

      get "foo"

      assert_not last_response.headers.has_key?("Cache-Control"), "Cache-Control should not be set"
    end

    test "headers for static files are configurable" do
      app_file "public/about.html", "static"
      add_to_config <<-CONFIG
        config.public_file_server.headers = {
          "Access-Control-Allow-Origin" => "http://rubyonrails.org",
          "Cache-Control"               => "public, max-age=60"
        }
      CONFIG

      require "#{app_path}/config/environment"

      get "/about.html"

      assert_equal "http://rubyonrails.org", last_response.headers["Access-Control-Allow-Origin"]
      assert_equal "public, max-age=60",     last_response.headers["Cache-Control"]
    end

    test "public_file_server.index_name defaults to 'index'" do
      app_file "public/index.html", "/index.html"

      require "#{app_path}/config/environment"

      get "/"

      assert_equal "/index.html\n", last_response.body
    end

    test "public_file_server.index_name configurable" do
      app_file "public/other-index.html", "/other-index.html"
      add_to_config "config.public_file_server.index_name = 'other-index'"

      require "#{app_path}/config/environment"

      get "/"

      assert_equal "/other-index.html\n", last_response.body
    end
  end
end
