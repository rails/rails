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

  test "can hook and dispatch actionable errors on specialized exceptions" do
    @app = ActionDispatch::ActionableExceptions.new(-> env do
      foo # This is a NameError. Let it happen!
    end)

    custom_error = Class.new(StandardError) do
      include ActiveSupport::ActionableError
    end

    ActionDispatch::ActionableExceptions.on NameError do |err|
      raise custom_error if err.name == :foo
    end

    assert_raise ActiveSupport::ActionableError do
      get "/"
    end
  ensure
    ActionDispatch::ActionableExceptions.hooks.clear
  end
end
