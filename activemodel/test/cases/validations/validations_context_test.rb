# encoding: utf-8
require 'cases/helper'

require 'models/topic'

class ValidationsContextTest < ActiveModel::TestCase

  def teardown
    Topic.reset_callbacks(:validate)
    Topic._validators.clear
  end

  ERROR_MESSAGE = "Validation error from validator"

  class ValidatorThatAddsErrors < ActiveModel::Validator
    def validate(record)
      record.errors[:base] << ERROR_MESSAGE
    end
  end

  test "with a class that adds errors on create and validating a new model with no arguments" do
    Topic.validates_with(ValidatorThatAddsErrors, :on => :create)
    topic = Topic.new
    assert topic.valid?, "Validation doesn't run on valid? if 'on' is set to create"
  end

  test "with a class that adds errors on update and validating a new model" do
    Topic.validates_with(ValidatorThatAddsErrors, :on => :update)
    topic = Topic.new
    assert topic.valid?(:create), "Validation doesn't run on create if 'on' is set to update"
  end

  test "with a class that adds errors on create and validating a new model" do
    Topic.validates_with(ValidatorThatAddsErrors, :on => :create)
    topic = Topic.new
    assert topic.invalid?(:create), "Validation does run on create if 'on' is set to create"
    assert topic.errors[:base].include?(ERROR_MESSAGE)
  end
end