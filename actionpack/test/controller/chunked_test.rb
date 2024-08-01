# frozen_string_literal: true

require "stringio"
require "abstract_unit"

class ChunkedTest < ActionDispatch::IntegrationTest
  class ChunkedController < ApplicationController
    def chunk
      render json: {
        raw_post: request.raw_post,
        content_length: request.content_length
      }
    end
  end

  # The TestInput class prevents Rack::MockRequest from adding a Content-Length when the method `size` is defined
  class TestInput < StringIO
    undef_method :size
  end

  test "parses request raw_post correctly when request has Transfer-Encoding header without a Content-Length value" do
    @app = self.class.build_app
    @app.routes.draw do
      post "chunked", to: ChunkedController.action(:chunk)
    end

    post "/chunked", params: TestInput.new("foo=bar"), headers: { "Transfer-Encoding" => "gzip, chunked;foo=bar" }

    assert_equal 7, response.parsed_body["content_length"]
    assert_equal "foo=bar", response.parsed_body["raw_post"]
  end
end
