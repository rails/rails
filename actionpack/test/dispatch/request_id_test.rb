# frozen_string_literal: true

require "abstract_unit"

class RequestIdTest < ActiveSupport::TestCase
  test "passing on the request id from the outside" do
    assert_equal "external-uu-rid", stub_request({ "HTTP_X_REQUEST_ID" => "external-uu-rid" }).request_id
  end

  test "passing on the request id via a configured header" do
    assert_equal "external-uu-rid", stub_request({ "HTTP_TRACER_ID" => "external-uu-rid" }, header: "tracer-id").request_id
  end

  test "ensure that only alphanumeric uurids are accepted" do
    assert_equal "X-Hacked-HeaderStuff", stub_request({ "HTTP_X_REQUEST_ID" => "; X-Hacked-Header: Stuff" }).request_id
  end

  test "accept Apache mod_unique_id format" do
    mod_unique_id = "abcxyz@ABCXYZ-0123456789"
    assert_equal mod_unique_id, stub_request({ "HTTP_X_REQUEST_ID" => mod_unique_id }).request_id
  end

  test "ensure that 255 char limit on the request id is being enforced" do
    assert_equal "X" * 255, stub_request({ "HTTP_X_REQUEST_ID" => "X" * 500 }).request_id
  end

  test "generating a request id when none is supplied" do
    assert_match(/\w+-\w+-\w+-\w+-\w+/, stub_request.request_id)
  end

  test "uuid alias" do
    assert_equal "external-uu-rid", stub_request({ "HTTP_X_REQUEST_ID" => "external-uu-rid" }).uuid
  end

  private
    def stub_request(env = {}, header: "x-request-id")
      app = lambda { |_env| [ 200, {}, [] ] }
      env = Rack::MockRequest.env_for("", env)

      Rack::Lint.new(
        ActionDispatch::RequestId.new(
          Rack::Lint.new(app),
          header: header,
        )
      ).call(env)

      ActionDispatch::Request.new(env)
    end
end

class RequestIdResponseTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def index
      head :ok
    end
  end

  setup do
    @header = "X-Request-Id"
  end

  test "request id is passed all the way to the response" do
    with_test_route_set do
      get "/"
      assert_match(/\w+/, @response.headers["X-Request-Id"])
    end
  end

  test "request id given on request is passed all the way to the response" do
    with_test_route_set do
      get "/", headers: { "HTTP_X_REQUEST_ID" => "X" * 500 }
      assert_equal "X" * 255, @response.headers["X-Request-Id"]
    end
  end

  test "using a custom request_id header key" do
    @header = "X-Tracer-Id"
    with_test_route_set do
      get "/"
      assert_match(/\w+/, @response.headers["X-Tracer-Id"])
    end
  end

  private
    def app
      @app ||= self.class.build_app do |middleware|
        middleware.use Rack::Lint
        middleware.use ActionDispatch::RequestId, header: @header
        middleware.use Rack::Lint
      end
    end

    def with_test_route_set(header: "X-Request-Id")
      with_routing do |set|
        set.draw do
          get "/", to: ::RequestIdResponseTest::TestController.action(:index)
        end

        yield
      end
    end
end
