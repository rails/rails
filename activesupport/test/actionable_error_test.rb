# frozen_string_literal: true

require "abstract_unit"
require "active_support/actionable_error"

class ActionableErrorTest < ActiveSupport::TestCase
  NonActionableError = Class.new(StandardError)

  class DispatchableError < StandardError
    include ActiveSupport::ActionableError

    class_attribute :flip1, default: false
    class_attribute :flip2, default: false

    action "Flip 1" do
      self.flip1 = true
    end

    action "Flip 2" do
      self.flip2 = true
    end
  end

  class TriggerableError < StandardError
    include ActiveSupport::ActionableError

    trigger RuntimeError do |error|
      error.to_s.match?(/Trigger action/)
    end
  end

  test "returns all action of an actionable error" do
    assert_equal ["Flip 1", "Flip 2"], ActiveSupport::ActionableError.actions(DispatchableError).keys
    assert_equal ["Flip 1", "Flip 2"], ActiveSupport::ActionableError.actions(DispatchableError.new).keys
  end

  test "returns no actions for non-actionable errors" do
    assert ActiveSupport::ActionableError.actions(Exception).empty?
    assert ActiveSupport::ActionableError.actions(Exception.new).empty?
  end

  test "dispatches actions from error and name" do
    assert_changes "DispatchableError.flip1", from: false, to: true do
      ActiveSupport::ActionableError.dispatch DispatchableError, "Flip 1"
    end
  end

  test "cannot dispatch missing actions" do
    err = assert_raises ActiveSupport::ActionableError::NonActionable do
      ActiveSupport::ActionableError.dispatch NonActionableError, "action"
    end

    assert_equal 'Cannot find action "action"', err.to_s
  end

  test "triggers actionable error from existing one" do
    error = RuntimeError.new("Trigger action!")

    assert_raises TriggerableError do
      ActiveSupport::ActionableError.trigger_by(error)
    end
  end

  test "does not triggers actionable errors if the condition fails" do
    error = StandardError.new

    ActiveSupport::ActionableError.trigger_by(error)
  end
end
