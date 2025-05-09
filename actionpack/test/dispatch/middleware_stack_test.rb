# frozen_string_literal: true

require "abstract_unit"

class MiddlewareStackTest < ActiveSupport::TestCase
  class Base
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    end
  end

  class FooMiddleware < Base; end
  class BarMiddleware < Base; end

  def setup
    @stack = ActionDispatch::MiddlewareStack.new
    @stack.use FooMiddleware
    @stack.use BarMiddleware
  end

  test "instruments the execution of middlewares" do
    notification_name = "process_middleware.action_dispatch"

    assert_notifications_count(notification_name, 2) do
      assert_notification(notification_name, { middleware: "MiddlewareStackTest::BarMiddleware" }) do
        assert_notification(notification_name, { middleware: "MiddlewareStackTest::FooMiddleware" }) do
          app = Rack::Lint.new(
            @stack.build(Rack::Lint.new(proc { |env| [200, {}, []] }))
          )

          env = Rack::MockRequest.env_for("", {})
          assert_nothing_raised do
            app.call(env)
          end
        end
      end
    end
  end
end
