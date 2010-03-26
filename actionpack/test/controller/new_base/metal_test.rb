require 'abstract_unit'

module MetalTest
  class MetalMiddleware < ActionController::Middleware
    def call(env)
      if env["PATH_INFO"] =~ /authed/
        app.call(env)
      else
        [401, headers, "Not authed!"]
      end
    end
  end

  class Endpoint
    def call(env)
      [200, {}, "Hello World"]
    end
  end

  class TestMiddleware < ActiveSupport::TestCase
    include RackTestUtils

    def setup
      @app = Rack::Builder.new do
        use MetalTest::MetalMiddleware
        run MetalTest::Endpoint.new
      end.to_app
    end

    test "it can call the next app by using @app" do
      env = Rack::MockRequest.env_for("/authed")
      response = @app.call(env)

      assert_equal "Hello World", body_to_string(response[2])
    end

    test "it can return a response using the normal AC::Metal techniques" do
      env = Rack::MockRequest.env_for("/")
      response = @app.call(env)

      assert_equal "Not authed!", body_to_string(response[2])
      assert_equal 401, response[0]
    end
  end
end
