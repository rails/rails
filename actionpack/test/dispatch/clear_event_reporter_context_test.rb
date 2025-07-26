# frozen_string_literal: true

require "abstract_unit"

class ClearEventReporterContextTest < ActiveSupport::TestCase
  def setup
    @app = ->(env) { [200, {}, ["Hello"]] }
    @middleware = ActionDispatch::ClearEventReporterContext.new(@app)
    @reporter = ActiveSupport.event_reporter
  end

  test "clears event reporter context in response finished callback" do
    @reporter.set_context(shop_id: 123)

    env = {}
    @middleware.call(env)

    assert env["rack.response_finished"]
    assert_equal 1, env["rack.response_finished"].length

    env["rack.response_finished"].each(&:call)

    assert_equal({}, @reporter.context)
  end

  test "clears event reporter context when exception is raised" do
    @reporter.set_context(shop_id: 123)

    exception_app = ->(env) { raise StandardError, "Test exception" }
    exception_middleware = ActionDispatch::ClearEventReporterContext.new(exception_app)

    env = {}
    assert_raises(StandardError) do
      exception_middleware.call(env)
    end

    assert_equal({}, @reporter.context)
  end
end
