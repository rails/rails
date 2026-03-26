# frozen_string_literal: true

require "cases/helper"

class Dog
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  attr_accessor :name, :history

  def initialize
    @history = []
  end
end

class DogWithMethodCallbacks < Dog
  before_validation :set_before_validation_marker
  after_validation :set_after_validation_marker

  def set_before_validation_marker; history << "before_validation_marker"; end
  def set_after_validation_marker;  history << "after_validation_marker" ; end
end

class DogValidatorsAreProc < Dog
  before_validation { history << "before_validation_marker" }
  after_validation  { history << "after_validation_marker" }
end

class DogWithTwoValidators < Dog
  before_validation { history << "before_validation_marker1" }
  before_validation { history << "before_validation_marker2" }
end

class DogBeforeValidatorReturningFalse < Dog
  before_validation { false }
  before_validation { history << "before_validation_marker2" }
end

class DogBeforeValidatorThrowingAbort < Dog
  before_validation { throw :abort }
  before_validation { history << "before_validation_marker2" }
end

class DogAfterValidatorReturningFalse < Dog
  after_validation { false }
  after_validation { history << "after_validation_marker" }
end

class DogWithMissingName < Dog
  before_validation { history << "before_validation_marker" }
  validates_presence_of :name
end

class DogValidatorWithOnCondition < Dog
  before_validation :set_before_validation_marker, on: :create
  after_validation :set_after_validation_marker, on: :create

  def set_before_validation_marker; history << "before_validation_marker"; end
  def set_after_validation_marker;  history << "after_validation_marker" ; end
end

class DogValidatorWithOnMultipleCondition < Dog
  before_validation :set_before_validation_marker_on_context_a, on: :context_a
  before_validation :set_before_validation_marker_on_context_b, on: :context_b
  before_validation :set_before_validation_marker_except_on_context_a, except_on: :context_a
  after_validation :set_after_validation_marker_on_context_a, on: :context_a
  after_validation :set_after_validation_marker_on_context_b, on: :context_b
  after_validation :set_after_validation_marker_except_on_context_a, except_on: :context_a

  def set_before_validation_marker_on_context_a; history << "before_validation_marker on context_a"; end
  def set_before_validation_marker_on_context_b; history << "before_validation_marker on context_b"; end
  def set_before_validation_marker_except_on_context_a; history << "before_validation_marker except on context_a"; end
  def set_after_validation_marker_on_context_a;  history << "after_validation_marker on context_a" ; end
  def set_after_validation_marker_on_context_b;  history << "after_validation_marker on context_b" ; end
  def set_after_validation_marker_except_on_context_a;  history << "after_validation_marker except on context_a" ; end
end

class DogValidatorWithIfCondition < Dog
  before_validation :set_before_validation_marker1, if: -> { true }
  before_validation :set_before_validation_marker2, if: -> { false }

  after_validation :set_after_validation_marker1, if: -> { true }
  after_validation :set_after_validation_marker2, if: -> { false }

  def set_before_validation_marker1; history << "before_validation_marker1"; end
  def set_before_validation_marker2; history << "before_validation_marker2" ; end

  def set_after_validation_marker1; history << "after_validation_marker1"; end
  def set_after_validation_marker2; history << "after_validation_marker2" ; end
end

class DogWithAroundValidation < Dog
  around_validation :wrap_validation

  def wrap_validation
    history << "around_validation_before"
    yield
    history << "around_validation_after"
  end
end

class DogWithAroundValidationAsProc < Dog
  around_validation do |_, blk|
    history << "around_validation_before"
    blk.call
    history << "around_validation_after"
  end
end

class DogWithAroundAndBeforeAfterValidation < Dog
  before_validation { history << "before_validation" }
  around_validation do |_, blk|
    history << "around_validation_before"
    blk.call
    history << "around_validation_after"
  end
  after_validation { history << "after_validation" }
end

class DogValidatorWithAroundOnCondition < Dog
  around_validation :wrap_validation, on: :create

  def wrap_validation
    history << "around_validation_before"
    yield
    history << "around_validation_after"
  end
end

class DogValidatorWithAroundIfCondition < Dog
  around_validation :set_around_validation_marker1, if: -> { true }
  around_validation :set_around_validation_marker2, if: -> { false }

  def set_around_validation_marker1
    history << "around_validation_marker1_before"
    yield
    history << "around_validation_marker1_after"
  end

  def set_around_validation_marker2
    history << "around_validation_marker2_before"
    yield
    history << "around_validation_marker2_after"
  end
end

class CallbacksWithMethodNamesShouldBeCalled < ActiveModel::TestCase
  def test_if_condition_is_respected_for_before_validation
    d = DogValidatorWithIfCondition.new
    d.valid?
    assert_equal ["before_validation_marker1", "after_validation_marker1"], d.history
  end

  def test_on_condition_is_respected_for_validation_with_matching_context
    d = DogValidatorWithOnCondition.new
    d.valid?(:create)
    assert_equal ["before_validation_marker", "after_validation_marker"], d.history
  end

  def test_on_condition_is_respected_for_validation_without_matching_context
    d = DogValidatorWithOnCondition.new
    d.valid?(:save)
    assert_equal [], d.history
  end

  def test_on_condition_is_respected_for_validation_without_context
    d = DogValidatorWithOnCondition.new
    d.valid?
    assert_equal [], d.history
  end

  def test_on_multiple_condition_is_respected_for_validation_with_matching_context
    d = DogValidatorWithOnMultipleCondition.new
    d.valid?(:context_a)
    assert_equal ["before_validation_marker on context_a", "after_validation_marker on context_a"], d.history

    d = DogValidatorWithOnMultipleCondition.new
    d.valid?(:context_b)
    assert_equal [
      "before_validation_marker on context_b",
      "before_validation_marker except on context_a",
      "after_validation_marker on context_b",
      "after_validation_marker except on context_a"
    ], d.history

    d = DogValidatorWithOnMultipleCondition.new
    d.valid?([:context_a, :context_b])
    assert_equal([
      "before_validation_marker on context_a",
      "before_validation_marker on context_b",
      "after_validation_marker on context_a",
      "after_validation_marker on context_b"
    ], d.history)
  end

  def test_on_multiple_condition_is_respected_for_validation_without_matching_context
    d = DogValidatorWithOnMultipleCondition.new
    d.valid?(:save)
    assert_equal ["before_validation_marker except on context_a", "after_validation_marker except on context_a"], d.history
  end

  def test_on_multiple_condition_is_respected_for_validation_without_context
    d = DogValidatorWithOnMultipleCondition.new
    d.valid?
    assert_equal ["before_validation_marker except on context_a", "after_validation_marker except on context_a"], d.history
  end

  def test_before_validation_and_after_validation_callbacks_should_be_called
    d = DogWithMethodCallbacks.new
    d.valid?
    assert_equal ["before_validation_marker", "after_validation_marker"], d.history
  end

  def test_before_validation_and_after_validation_callbacks_should_be_called_with_proc
    d = DogValidatorsAreProc.new
    d.valid?
    assert_equal ["before_validation_marker", "after_validation_marker"], d.history
  end

  def test_before_validation_and_after_validation_callbacks_should_be_called_in_declared_order
    d = DogWithTwoValidators.new
    d.valid?
    assert_equal ["before_validation_marker1", "before_validation_marker2"], d.history
  end

  def test_further_callbacks_should_not_be_called_if_before_validation_throws_abort
    d = DogBeforeValidatorThrowingAbort.new
    output = d.valid?
    assert_equal [], d.history
    assert_equal false, output
  end

  def test_further_callbacks_should_be_called_if_before_validation_returns_false
    d = DogBeforeValidatorReturningFalse.new
    output = d.valid?
    assert_equal ["before_validation_marker2"], d.history
    assert_equal true, output
  end

  def test_further_callbacks_should_be_called_if_after_validation_returns_false
    d = DogAfterValidatorReturningFalse.new
    d.valid?
    assert_equal ["after_validation_marker"], d.history
  end

  def test_validation_test_should_be_done
    d = DogWithMissingName.new
    output = d.valid?
    assert_equal ["before_validation_marker"], d.history
    assert_equal false, output
  end

  def test_before_validation_does_not_mutate_the_if_options_array
    opts = []

    Class.new(Dog) do
      before_validation(if: opts, on: :create) { }
    end

    assert_empty opts
  end

  def test_after_validation_does_not_mutate_the_if_options_array
    opts = []

    Class.new(Dog) do
      after_validation(if: opts, on: :create) { }
    end

    assert_empty opts
  end

  def test_around_validation_callback_should_be_called
    d = DogWithAroundValidation.new
    d.valid?
    assert_equal ["around_validation_before", "around_validation_after"], d.history
  end

  def test_around_validation_callback_should_be_called_with_proc
    d = DogWithAroundValidationAsProc.new
    d.valid?
    assert_equal ["around_validation_before", "around_validation_after"], d.history
  end

  def test_around_validation_wraps_before_and_after_callbacks
    d = DogWithAroundAndBeforeAfterValidation.new
    d.valid?
    assert_equal ["before_validation", "around_validation_before", "around_validation_after", "after_validation"], d.history
  end

  def test_on_condition_is_respected_for_around_validation_with_matching_context
    d = DogValidatorWithAroundOnCondition.new
    d.valid?(:create)
    assert_equal ["around_validation_before", "around_validation_after"], d.history
  end

  def test_on_condition_is_respected_for_around_validation_without_matching_context
    d = DogValidatorWithAroundOnCondition.new
    d.valid?(:save)
    assert_equal [], d.history
  end

  def test_on_condition_is_respected_for_around_validation_without_context
    d = DogValidatorWithAroundOnCondition.new
    d.valid?
    assert_equal [], d.history
  end

  def test_if_condition_is_respected_for_around_validation
    d = DogValidatorWithAroundIfCondition.new
    d.valid?
    assert_equal ["around_validation_marker1_before", "around_validation_marker1_after"], d.history
  end
end
