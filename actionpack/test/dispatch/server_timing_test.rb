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
    @middlewares = [Rack::Lint, ActionDispatch::ServerTiming, Rack::Lint]
    @header_name = ActionDispatch::Constants::SERVER_TIMING
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
      assert_match(/\w+/, @response.headers[@header_name])
    end
  end

  test "includes default action controller events duration" do
    with_test_route_set do
      get "/"
      assert_match(/start_processing.action_controller;dur=\w+/, @response.headers[@header_name])
      assert_match(/process_action.action_controller;dur=\w+/, @response.headers[@header_name])
    end
  end

  test "includes custom active support events duration" do
    with_test_route_set do
      get "/id"
      assert_match(/custom.event;dur=\w+/, @response.headers[@header_name])
    end
  end

  test "events are tracked by thread" do
    barrier = Concurrent::CyclicBarrier.new(2)

    stub_app = -> (env) {
      env["action_dispatch.test"].call
      [200, {}, "ok"]
    }
    app = Rack::Lint.new(
      ActionDispatch::ServerTiming.new(Rack::Lint.new(stub_app))
    )

    t1 = Thread.new do
      proc = -> {
        barrier.wait
        barrier.wait
      }
      env = Rack::MockRequest.env_for("", { "action_dispatch.test" => proc })
      app.call(env)
    end

    t2 = Thread.new do
      barrier.wait
      proc = -> {
        ActiveSupport::Notifications.instrument("custom.event") do
          true
        end
      }
      env = Rack::MockRequest.env_for("", { "action_dispatch.test" => proc })
      response = app.call(env)

      barrier.wait

      response
    end

    headers1 = t1.value[1]
    headers2 = t2.value[1]

    assert_match(/custom.event;dur=\w+/, headers2[@header_name])
    assert_no_match(/custom.event;dur=\w+/, headers1[@header_name])
  end

  test "does not overwrite existing header values" do
    @middlewares << Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        header_name = ActionDispatch::Constants::SERVER_TIMING
        headers[header_name] = [headers[header_name], %(entry;desc="description")].compact.join(", ")
        [ status, headers, body ]
      end
    end

    with_test_route_set do
      get "/"
      assert_match(/entry;desc="description"/, @response.headers[@header_name])
      assert_match(/start_processing.action_controller;dur=\w+/, @response.headers[@header_name])
    end
  end

  test "nested events of the same name are not double counted" do
    outer_sleep = 0.02
    inner_sleep = 0.02

    stub_app = ->(_env) {
      ActiveSupport::Notifications.instrument("render_partial.action_view") do
        sleep outer_sleep
        ActiveSupport::Notifications.instrument("render_partial.action_view") do
          sleep inner_sleep
        end
      end
      [200, {}, ["ok"]]
    }
    app = ActionDispatch::ServerTiming.new(stub_app)

    _status, headers, = app.call(Rack::MockRequest.env_for("/"))
    duration = server_timing_duration(headers[@header_name], "render_partial.action_view")

    wall_clock_ms = (outer_sleep + inner_sleep) * 1000
    # Inclusive sum would be ~1.5–2× wall clock; exclusive stays near wall clock.
    assert_in_delta wall_clock_ms, duration, wall_clock_ms * 0.5
    assert_operator duration, :<, wall_clock_ms * 1.5
  end

  test "sibling events of the same name still accumulate" do
    first_sleep = 0.02
    second_sleep = 0.02

    stub_app = ->(_env) {
      ActiveSupport::Notifications.instrument("render_partial.action_view") do
        sleep first_sleep
      end
      ActiveSupport::Notifications.instrument("render_partial.action_view") do
        sleep second_sleep
      end
      [200, {}, ["ok"]]
    }
    app = ActionDispatch::ServerTiming.new(stub_app)

    _status, headers, = app.call(Rack::MockRequest.env_for("/"))
    duration = server_timing_duration(headers[@header_name], "render_partial.action_view")

    wall_clock_ms = (first_sleep + second_sleep) * 1000
    assert_in_delta wall_clock_ms, duration, wall_clock_ms * 0.5
  end

  test "nested events of a different name are not subtracted" do
    stub_app = ->(_env) {
      ActiveSupport::Notifications.instrument("render_partial.action_view") do
        sleep 0.01
        ActiveSupport::Notifications.instrument("sql.active_record") do
          sleep 0.02
        end
        sleep 0.01
      end
      [200, {}, ["ok"]]
    }
    app = ActionDispatch::ServerTiming.new(stub_app)

    _status, headers, = app.call(Rack::MockRequest.env_for("/"))
    partial_duration = server_timing_duration(headers[@header_name], "render_partial.action_view")
    sql_duration = server_timing_duration(headers[@header_name], "sql.active_record")

    assert_operator partial_duration, :>, sql_duration
    assert_in_delta 40, partial_duration, 20
    assert_in_delta 20, sql_duration, 15
  end

  private
    def app
      @app ||= self.class.build_app do |middleware|
        @middlewares.each { |m| middleware.use m }
      end
    end

    def with_test_route_set
      with_routing do |set|
        set.draw do
          get "/", to: ::ServerTimingTest::TestController.action(:index)
          get "/id", to: ::ServerTimingTest::TestController.action(:show)
          post "/", to: ::ServerTimingTest::TestController.action(:create)
        end

        yield
      end
    end

    def server_timing_duration(header, name)
      header.to_s.split(",").each do |entry|
        entry_name, *params = entry.strip.split(";")
        next unless entry_name == name

        dur = params.find { |param| param.start_with?("dur=") }
        return dur.delete_prefix("dur=").to_f if dur
      end
      flunk "missing Server-Timing entry for #{name} in #{header.inspect}"
    end
end
