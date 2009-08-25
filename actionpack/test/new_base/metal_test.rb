require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module MetalTest
  class MetalMiddleware < ActionController::Metal
    def index
      if env["PATH_INFO"] =~ /authed/
        self.response = app.call(env)
      else
        self.response_body = "Not authed!"
        self.status = 401
      end
    end
  end

  class Endpoint
    def call(env)
      [200, {}, "Hello World"]
    end
  end

  class TestMiddleware < ActiveSupport::TestCase
    def setup
      @app = Rack::Builder.new do
        use MetalMiddleware.middleware(:index)
        run Endpoint.new
      end.to_app
    end

    test "it can call the next app by using @app" do
      env = Rack::MockRequest.env_for("/authed")
      response = @app.call(env)

      assert_equal "Hello World", response[2]
    end

    test "it can return a response using the normal AC::Metal techniques" do
      env = Rack::MockRequest.env_for("/")
      response = @app.call(env)

      assert_equal "Not authed!", response[2]
      assert_equal 401, response[0]
    end
  end
end

