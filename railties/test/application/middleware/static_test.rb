# encoding: utf-8
require 'isolation/abstract_unit'
require 'rack/test'

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
      app_file "public/foo.html", 'static'

      require "#{app_path}/config/environment"

      get 'foo'

      assert_not last_response.headers.has_key?('Cache-Control'), "Cache-Control should not be set"
    end
  end
end
