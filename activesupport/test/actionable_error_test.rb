# frozen_string_literal: true

require "abstract_unit"
require "active_support/actionable_error"

class ActionableErrorTest < ActiveSupport::TestCase
  class NonActionableError < StandardError
  end

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

  test "can get all action of an actionable error" do
    assert_equal ["Flip 1", "Flip 2"], ActiveSupport::ActionableError.actions(DispatchableError).keys
    assert_equal ["Flip 1", "Flip 2"], ActiveSupport::ActionableError.actions(DispatchableError.new).keys
  end

  test "cannot get actions from non-actionable errors" do
    assert_raises ActiveSupport::ActionableError::NonActionable do
      ActiveSupport::ActionableError.actions(NonActionableError)
    end
  end

  test "dispatches actions from class and a label" do
    assert_changes "DispatchableError.flip1", from: false, to: true do
      ActiveSupport::ActionableError.dispatch DispatchableError, "Flip 1"
    end
  end

  test "dispatches actions from class name and a label" do
    assert_changes "DispatchableError.flip2", from: false, to: true do
      ActiveSupport::ActionableError.dispatch DispatchableError.name, "Flip 2"
    end
  end

  test "cannot dispatch errors that do not include ActiveSupport::ActionableError" do
    err = assert_raises ActiveSupport::ActionableError::NonActionable do
      ActiveSupport::ActionableError.dispatch NonActionableError, "action"
    end

    assert_equal <<~EXPECTED.chop, err.to_s
      ActionableErrorTest::NonActionableError is non-actionable
    EXPECTED
  end
end
