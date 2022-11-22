# frozen_string_literal: true

require "abstract_unit"

class ServerTimingTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def index
      head :ok
    end

    def show
      ActiveSupport::Notifications.instrument("custom.event") do
        true
      end
      head :ok
    end

    def create
      ActiveSupport::Notifications.instrument("custom.event") do
        raise
      end
    end
  end

  setup do
    @middlewares = [ActionDispatch::ServerTiming]
  end

  teardown do
    # Avoid leaking subscription into other tests
    # This will break any active instance of the middleware, but we don't
    # expect there to be any outside of this file.
    ActionDispatch::ServerTiming.unsubscribe
  end

  test "server timing header is included in the response" do
    with_test_route_set do
      get "/"
      assert_match(/\w+/, @response.headers["Server-Timing"])
    end
  end

  test "includes default action controller events duration" do
    with_test_route_set do
      get "/"
      assert_match(/start_processing.action_controller;dur=\w+/, @response.headers["Server-Timing"])
      assert_match(/process_action.action_controller;dur=\w+/, @response.headers["Server-Timing"])
    end
  end

  test "includes custom active support events duration" do
    with_test_route_set do
      get "/id"
      assert_match(/custom.event;dur=\w+/, @response.headers["Server-Timing"])
    end
  end

  test "events are tracked by thread" do
    barrier = Concurrent::CyclicBarrier.new(2)

    stub_app = -> (env) {
      env["proc"].call
      [200, {}, "ok"]
    }
    app = ActionDispatch::ServerTiming.new(stub_app)

    t1 = Thread.new do
      app.call({ "proc" => -> {
        barrier.wait
        barrier.wait
      } })
    end

    t2 = Thread.new do
      barrier.wait

      response = app.call({ "proc" => -> {
        ActiveSupport::Notifications.instrument("custom.event") do
          true
        end
      } })

      barrier.wait

      response
    end

    headers1 = t1.value[1]
    headers2 = t2.value[1]

    assert_match(/custom.event;dur=\w+/, headers2["Server-Timing"])
    assert_no_match(/custom.event;dur=\w+/, headers1["Server-Timing"])
  end

  test "does not overwrite existing header values" do
    @middlewares << Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        headers["Server-Timing"] = [headers["Server-Timing"], %(entry;desc="description")].compact.join(", ")
        [ status, headers, body ]
      end
    end

    with_test_route_set do
      get "/"
      assert_match(/entry;desc="description"/, @response.headers["Server-Timing"])
      assert_match(/start_processing.action_controller;dur=\w+/, @response.headers["Server-Timing"])
    end
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do
          get "/", to: ::ServerTimingTest::TestController.action(:index)
          get "/id", to: ::ServerTimingTest::TestController.action(:show)
          post "/", to: ::ServerTimingTest::TestController.action(:create)
        end

        @app = self.class.build_app(set) do |middleware|
          @middlewares.each { |m| middleware.use m }
        end

        yield
      end
    end
end
