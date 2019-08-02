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
  after_validation :set_after_validation_marker_on_context_a, on: :context_a
  after_validation :set_after_validation_marker_on_context_b, on: :context_b

  def set_before_validation_marker_on_context_a; history << "before_validation_marker on context_a"; end
  def set_before_validation_marker_on_context_b; history << "before_validation_marker on context_b"; end
  def set_after_validation_marker_on_context_a;  history << "after_validation_marker on context_a" ; end
  def set_after_validation_marker_on_context_b;  history << "after_validation_marker on context_b" ; end
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
    assert_equal ["before_validation_marker on context_b", "after_validation_marker on context_b"], d.history

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
    assert_equal [], d.history
  end

  def test_on_multiple_condition_is_respected_for_validation_without_context
    d = DogValidatorWithOnMultipleCondition.new
    d.valid?
    assert_equal [], d.history
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
end
