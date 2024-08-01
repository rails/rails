# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class CacheTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      require "rack/test"
      extend Rack::Test::Methods

      add_to_env_config "production", "config.cache_store = :memory_store"
      add_to_env_config "production", "config.action_dispatch.rack_cache = true"
    end

    def teardown
      teardown_app
    end

    def simple_controller
      controller :expires, <<-RUBY
        class ExpiresController < ApplicationController
          def expires_header
            expires_in 10, public: !params[:private]
            render plain: SecureRandom.hex(16)
          end

          def expires_etag
            render_conditionally(etag: "1")
          end

          def expires_last_modified
            $last_modified ||= Time.now.utc
            render_conditionally(last_modified: $last_modified)
          end

          def keeps_if_modified_since
            render plain: request.headers['If-Modified-Since']
          end
        private
          def render_conditionally(headers)
            if stale?(**headers.merge(public: !params[:private]))
              render plain: SecureRandom.hex(16)
            end
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get ':controller(/:action)'
        end
      RUBY
    end

    def test_cache_keeps_if_modified_since
      simple_controller
      expected = "Wed, 30 May 1984 19:43:31 GMT"

      get "/expires/keeps_if_modified_since", {}, { "HTTP_IF_MODIFIED_SINCE" => expected, "HTTPS" => "on" }

      assert_equal 200, last_response.status
      assert_equal expected, last_response.body, "cache should have kept If-Modified-Since"
    end

    def test_cache_is_disabled_in_dev_mode
      simple_controller
      app("development")

      get "/expires/expires_header"
      assert_nil last_response.headers["X-Rack-Cache"]

      body = last_response.body

      get "/expires/expires_header"
      assert_nil last_response.headers["X-Rack-Cache"]
      assert_not_equal body, last_response.body
    end

    def test_cache_works_with_expires
      simple_controller

      get "/expires/expires_header", {}, { "HTTPS" => "on" }
      assert_equal "miss, store", last_response.headers["X-Rack-Cache"]
      assert_equal "max-age=10, public", last_response.headers["Cache-Control"]

      body = last_response.body

      get "/expires/expires_header", {}, { "HTTPS" => "on" }

      assert_equal "fresh", last_response.headers["X-Rack-Cache"]

      assert_equal body, last_response.body
    end

    def test_cache_works_with_expires_private
      simple_controller

      get "/expires/expires_header", { private: true }, { "HTTPS" => "on" }
      assert_equal "miss",                last_response.headers["X-Rack-Cache"]
      assert_equal "private, max-age=10", last_response.headers["Cache-Control"]

      body = last_response.body

      get "/expires/expires_header", { private: true }, { "HTTPS" => "on" }
      assert_equal "miss",           last_response.headers["X-Rack-Cache"]
      assert_not_equal body,         last_response.body
    end

    def test_cache_works_with_etags
      simple_controller

      get "/expires/expires_etag", {}, { "HTTPS" => "on" }
      assert_equal "public", last_response.headers["Cache-Control"]
      assert_equal "miss, store", last_response.headers["X-Rack-Cache"]

      etag = last_response.headers["ETag"]

      get "/expires/expires_etag", {}, { "HTTP_IF_NONE_MATCH" => etag, "HTTPS" => "on" }
      assert_equal "stale, valid, store", last_response.headers["X-Rack-Cache"]
      assert_equal 304, last_response.status
      assert_equal "", last_response.body
    end

    def test_cache_works_with_etags_private
      simple_controller

      get "/expires/expires_etag", { private: true }, { "HTTPS" => "on" }
      assert_equal "miss",                                last_response.headers["X-Rack-Cache"]
      assert_equal "must-revalidate, private, max-age=0", last_response.headers["Cache-Control"]

      body = last_response.body
      etag = last_response.headers["ETag"]

      get "/expires/expires_etag", { private: true }, { "HTTP_IF_NONE_MATCH" => etag, "HTTPS" => "on" }
      assert_equal "miss", last_response.headers["X-Rack-Cache"]
      assert_not_equal body,   last_response.body
    end

    def test_cache_works_with_last_modified
      simple_controller

      get "/expires/expires_last_modified", {}, { "HTTPS" => "on" }
      assert_equal "public", last_response.headers["Cache-Control"]
      assert_equal "miss, store", last_response.headers["X-Rack-Cache"]

      last = last_response.headers["Last-Modified"]

      get "/expires/expires_last_modified", {}, { "HTTP_IF_MODIFIED_SINCE" => last, "HTTPS" => "on" }
      assert_equal "stale, valid, store", last_response.headers["X-Rack-Cache"]
      assert_equal 304, last_response.status
      assert_equal "", last_response.body
    end

    def test_cache_works_with_last_modified_private
      simple_controller

      get "/expires/expires_last_modified", { private: true }, { "HTTPS" => "on" }
      assert_equal "miss",                                last_response.headers["X-Rack-Cache"]
      assert_equal "must-revalidate, private, max-age=0", last_response.headers["Cache-Control"]

      body = last_response.body
      last = last_response.headers["Last-Modified"]

      get "/expires/expires_last_modified", { private: true }, { "HTTP_IF_MODIFIED_SINCE" => last, "HTTPS" => "on" }
      assert_equal "miss", last_response.headers["X-Rack-Cache"]
      assert_not_equal body,   last_response.body
    end
  end
end
