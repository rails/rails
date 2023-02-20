# frozen_string_literal: true

require "isolation/abstract_unit"
require "stringio"
require "rack/test"
require "active_support/core_ext/module/delegation"

module RailtiesTest
  class HttpRequestTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          post "posts", to: "posts#create"
        end
      RUBY

      controller "posts", <<-RUBY
        class PostsController < ApplicationController
          def create
            render json: {
              raw_post: request.raw_post,
              content_length: request.content_length
            }
          end
        end
      RUBY
    end

    def teardown
      teardown_app
    end

    # The TestInput class prevents Rack::MockRequest from adding a Content-Length when the method `size` is defined
    class TestInput < StringIO
      undef_method :size
    end

    test "parses request raw_post correctly when request has Transfer-Encoding header without a Content-Length value" do
      require "#{app_path}/config/environment"

      header "Transfer-Encoding", "gzip, chunked;foo=bar"
      post "/posts", TestInput.new("foo=bar")

      json_response = JSON.parse(last_response.body)
      assert_equal 7, json_response["content_length"]
      assert_equal "foo=bar", json_response["raw_post"]
    end
  end
end
