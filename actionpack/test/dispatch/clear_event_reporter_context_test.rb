# frozen_string_literal: true

require "abstract_unit"

class ClearEventReporterContextTest < ActiveSupport::TestCase
  def setup
    @app = ->(env) { [200, {}, ["Hello"]] }
    @reporter = ActiveSupport.event_reporter
  end

  test "clears event reporter context in response finished callback" do
    @reporter.set_context(shop_id: 123)

    env = Rack::MockRequest.env_for("", { "rack.response_finished" => [] })
    middleware(@app).call(env)

    assert env["rack.response_finished"]
    assert_equal 1, env["rack.response_finished"].length

    env["rack.response_finished"].each(&:call)

    assert_equal({}, @reporter.context)
  end

  test "clears event reporter context via Rack::BodyProxy when rack.response_finished is not supported" do
    @reporter.set_context(shop_id: 123)

    env = Rack::MockRequest.env_for("", {})
    response = middleware(@app).call(env)

    assert_equal({ shop_id: 123 }, @reporter.context)

    body = response[2]
    body.close

    assert_equal({}, @reporter.context)
  end

  test "clears event reporter context via rack.response_finished when exception is raised" do
    @reporter.set_context(shop_id: 123)

    env = Rack::MockRequest.env_for("", { "rack.response_finished" => [] })
    exception_app = ->(env) { raise StandardError, "Test exception" }
    assert_raises(StandardError) do
      middleware(exception_app).call(env)
    end

    assert_equal({}, @reporter.context)
  end

  test "clears event reporter context when exception is raised and rack.response_finished is not supported" do
    @reporter.set_context(shop_id: 123)

    exception_app = ->(env) { raise StandardError, "Test exception" }
    env = Rack::MockRequest.env_for("", {})  # Add missing env variable
    assert_raises(StandardError) do
      middleware(exception_app).call(env)
    end

    assert_equal({}, @reporter.context)
  end

  private
    def middleware(inner_app)
      Rack::Lint.new(ActionDispatch::ClearEventReporterContext.new(Rack::Lint.new(inner_app)))
    end
end
