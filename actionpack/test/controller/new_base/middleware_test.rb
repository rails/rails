require 'abstract_unit'

module MiddlewareTest
  class MyMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      result = @app.call(env)
      result[1]["Middleware-Test"] = "Success"
      result[1]["Middleware-Order"] = "First"
      result
    end
  end

  class ExclaimerMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      result = @app.call(env)
      result[1]["Middleware-Order"] << "!"
      result
    end
  end

  class MyController < ActionController::Metal
    use MyMiddleware

    middleware.insert_before MyMiddleware, ExclaimerMiddleware

    def index
      self.response_body = "Hello World"
    end
  end

  class InheritedController < MyController
  end

  module MiddlewareTests
    extend ActiveSupport::Testing::Declarative

    test "middleware that is 'use'd is called as part of the Rack application" do
      result = @app.call(env_for("/"))
      assert_equal "Hello World", RackTestUtils.body_to_string(result[2])
      assert_equal "Success", result[1]["Middleware-Test"]
    end

    test "the middleware stack is exposed as 'middleware' in the controller" do
      result = @app.call(env_for("/"))
      assert_equal "First!", result[1]["Middleware-Order"]
    end
  end

  class TestMiddleware < ActiveSupport::TestCase
    include MiddlewareTests

    def setup
      @app = MyController.action(:index)
    end

    def env_for(url)
      Rack::MockRequest.env_for(url)
    end
  end

  class TestInheritedMiddleware < TestMiddleware
    def setup
      @app = InheritedController.action(:index)
    end

    test "middleware inherits" do
    end
  end
end
