# frozen_string_literal: true

require "abstract_unit"

class ActionableExceptionsTest < ActionDispatch::IntegrationTest
  Actions = []

  class ActionError < StandardError
    include ActiveSupport::ActionableError

    action "Successful action" do
      Actions << "Action!"
    end

    action "Failed action" do
      raise "Inaction!"
    end
  end

  Noop = -> env { [200, {}, [""]] }

  setup do
    @app = ActionDispatch::ActionableExceptions.new(Noop)

    Actions.clear
  end

  test "dispatches an actionable error" do
    post ActionDispatch::ActionableExceptions.endpoint, params: {
      error: ActionError.name,
      action: "Successful action",
      location: "/",
    }

    assert_equal ["Action!"], Actions

    assert_equal 302, response.status
    assert_equal "/", response.headers["Location"]
  end

  test "cannot dispatch errors if not allowed" do
    post ActionDispatch::ActionableExceptions.endpoint, params: {
      error: ActionError.name,
      action: "Successful action",
      location: "/",
    }, headers: { "action_dispatch.show_exceptions" => false }

    assert_empty Actions
  end

  test "dispatched action can fail" do
    assert_raise RuntimeError do
      post ActionDispatch::ActionableExceptions.endpoint, params: {
        error: ActionError.name,
        action: "Failed action",
        location: "/",
      }
    end
  end

  test "cannot dispatch non-actionable errors" do
    assert_raise ActiveSupport::ActionableError::NonActionable do
      post ActionDispatch::ActionableExceptions.endpoint, params: {
        error: RuntimeError.name,
        action: "Inexistent action",
        location: "/",
      }
    end
  end

  test "cannot dispatch Inexistent errors" do
    assert_raise ActiveSupport::ActionableError::NonActionable do
      post ActionDispatch::ActionableExceptions.endpoint, params: {
        error: "",
        action: "Inexistent action",
        location: "/",
      }
    end
  end
end
