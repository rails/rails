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

  test "ensures it doesn't leak subscriptions when the app crashes" do
    with_test_route_set do
      post "/"
      assert_not ActiveSupport::Notifications.notifier.listening?("custom.event")
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
