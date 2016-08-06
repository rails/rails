require "abstract_unit"

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

  class BlockMiddleware
    attr_accessor :configurable_message
    def initialize(app, &block)
      @app = app
      yield(self) if block_given?
    end

    def call(env)
      result = @app.call(env)
      result[1]["Configurable-Message"] = configurable_message
      result
    end
  end

  class MyController < ActionController::Metal
    use BlockMiddleware do |config|
      config.configurable_message = "Configured by block."
    end
    use MyMiddleware
    middleware.insert_before MyMiddleware, ExclaimerMiddleware

    def index
      self.response_body = "Hello World"
    end
  end

  class InheritedController < MyController
  end

  class ActionsController < ActionController::Metal
    use MyMiddleware, :only => :show
    middleware.insert_before MyMiddleware, ExclaimerMiddleware, :except => :index

    def index
      self.response_body = "index"
    end

    def show
      self.response_body = "show"
    end
  end

  class TestMiddleware < ActiveSupport::TestCase
    def setup
      @app = MyController.action(:index)
    end

    test "middleware that is 'use'd is called as part of the Rack application" do
      result = @app.call(env_for("/"))
      assert_equal ["Hello World"], [].tap { |a| result[2].each { |x| a << x } }
      assert_equal "Success", result[1]["Middleware-Test"]
    end

    test "the middleware stack is exposed as 'middleware' in the controller" do
      result = @app.call(env_for("/"))
      assert_equal "First!", result[1]["Middleware-Order"]
    end

    test "middleware stack accepts block arguments" do
      result = @app.call(env_for("/"))
      assert_equal "Configured by block.", result[1]["Configurable-Message"]
    end

    test "middleware stack accepts only and except as options" do
      result = ActionsController.action(:show).call(env_for("/"))
      assert_equal "First!", result[1]["Middleware-Order"]

      result = ActionsController.action(:index).call(env_for("/"))
      assert_nil result[1]["Middleware-Order"]
    end

    def env_for(url)
      Rack::MockRequest.env_for(url)
    end
  end

  class TestInheritedMiddleware < TestMiddleware
    def setup
      @app = InheritedController.action(:index)
    end
  end
end
