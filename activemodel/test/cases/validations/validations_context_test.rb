# frozen_string_literal: true

require "cases/helper"

require "models/topic"

class ValidationsContextTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  ERROR_MESSAGE = "Validation error from validator"
  ANOTHER_ERROR_MESSAGE = "Another validation error from validator"

  class ValidatorThatAddsErrors < ActiveModel::Validator
    def validate(record)
      record.errors.add(:base, ERROR_MESSAGE)
    end
  end

  class AnotherValidatorThatAddsErrors < ActiveModel::Validator
    def validate(record)
      record.errors.add(:base, ANOTHER_ERROR_MESSAGE)
    end
  end

  test "with a class that adds errors on create and validating a new model with no arguments" do
    Topic.validates_with(ValidatorThatAddsErrors, on: :create)
    topic = Topic.new
    assert topic.valid?, "Validation doesn't run on valid? if 'on' is set to create"
  end

  test "with a class that adds errors on update and validating a new model" do
    Topic.validates_with(ValidatorThatAddsErrors, on: :update)
    topic = Topic.new
    assert topic.valid?(:create), "Validation doesn't run on create if 'on' is set to update"
  end

  test "with a class that adds errors on create and validating a new model" do
    Topic.validates_with(ValidatorThatAddsErrors, on: :create)
    topic = Topic.new
    assert topic.invalid?(:create), "Validation does run on create if 'on' is set to create"
    assert_includes topic.errors[:base], ERROR_MESSAGE
  end

  test "with a class that adds errors on multiple contexts and validating a new model" do
    Topic.validates_with(ValidatorThatAddsErrors, on: [:context1, :context2])

    topic = Topic.new
    assert topic.valid?, "Validation ran with no context given when 'on' is set to context1 and context2"

    assert topic.invalid?(:context1), "Validation did not run on context1 when 'on' is set to context1 and context2"
    assert_includes topic.errors[:base], ERROR_MESSAGE

    assert topic.invalid?(:context2), "Validation did not run on context2 when 'on' is set to context1 and context2"
    assert_includes topic.errors[:base], ERROR_MESSAGE
  end

  test "with a class that validating a model for a multiple contexts" do
    Topic.validates_with(ValidatorThatAddsErrors, on: :context1)
    Topic.validates_with(AnotherValidatorThatAddsErrors, on: :context2)

    topic = Topic.new
    assert topic.valid?, "Validation ran with no context given when 'on' is set to context1 and context2"

    assert topic.invalid?([:context1, :context2]), "Validation did not run on context1 when 'on' is set to context1 and context2"
    assert_includes topic.errors[:base], ERROR_MESSAGE
    assert_includes topic.errors[:base], ANOTHER_ERROR_MESSAGE
  end
end
