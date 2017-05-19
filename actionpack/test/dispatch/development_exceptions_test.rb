require "abstract_unit"

class DevelopmentExceptionsTest < ActionDispatch::IntegrationTest
  test "handles error with debug exceptions" do
    error = StandardError.new
    error.set_backtrace(caller)

    app = ActionDispatch::DevelopmentExceptions.new("#{FIXTURE_LOAD_PATH}/public")
    env = Rack::MockRequest.env_for "http://example.com/foo/42",
      "REMOTE_ADDR" => "124.123.123.123",
      "action_dispatch.show_detailed_exceptions" => true,
      "action_dispatch.original_path" => "/foo/42",
      "action_dispatch.unwrapped_exception" => error

    _, _, body = app.call(env)

    assert body.first["Action Controller: Exception caught"]
  end

  test "fallback to public exceptions if debug exceptions crashes" do
    app = ActionDispatch::DevelopmentExceptions.new("#{FIXTURE_LOAD_PATH}/public")
    env = Rack::MockRequest.env_for "http://example.com/foo/42",
      "REMOTE_ADDR" => "124.123.123.123",
      "PATH_INFO" => "/500"

    app.debug_exceptions.stub :render_exception, -> { nil } do
      _, _, body = app.call(env)

      assert_equal "500 error fixture\n", body.first
    end
  end
end
