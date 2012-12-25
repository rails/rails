# encoding: utf-8
require 'cases/helper'

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

  def set_before_validation_marker; self.history << 'before_validation_marker'; end
  def set_after_validation_marker;  self.history << 'after_validation_marker' ; end
end

class DogValidatorsAreProc < Dog
  before_validation { self.history << 'before_validation_marker' }
  after_validation  { self.history << 'after_validation_marker' }
end

class DogWithTwoValidators < Dog
  before_validation { self.history << 'before_validation_marker1' }
  before_validation { self.history << 'before_validation_marker2' }
end

class DogValidatorReturningFalse < Dog
  before_validation { false }
  before_validation { self.history << 'before_validation_marker2' }
end

class DogWithMissingName < Dog
  before_validation { self.history << 'before_validation_marker' }
  validates_presence_of :name
end

class CallbacksWithMethodNamesShouldBeCalled < ActiveModel::TestCase

  def test_before_validation_and_after_validation_callbacks_should_be_called
    d = DogWithMethodCallbacks.new
    d.valid?
    assert_equal ['before_validation_marker', 'after_validation_marker'], d.history
  end

  def test_before_validation_and_after_validation_callbacks_should_be_called_with_proc
    d = DogValidatorsAreProc.new
    d.valid?
    assert_equal ['before_validation_marker', 'after_validation_marker'], d.history
  end

  def test_before_validation_and_after_validation_callbacks_should_be_called_in_declared_order
    d = DogWithTwoValidators.new
    d.valid?
    assert_equal ['before_validation_marker1', 'before_validation_marker2'], d.history
  end

  def test_further_callbacks_should_not_be_called_if_before_validation_returns_false
    d = DogValidatorReturningFalse.new
    output = d.valid?
    assert_equal [], d.history
    assert_equal false, output
  end

  def test_validation_test_should_be_done
    d = DogWithMissingName.new
    output = d.valid?
    assert_equal ['before_validation_marker'], d.history
    assert_equal false, output
  end

end
