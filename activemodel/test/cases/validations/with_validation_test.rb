# encoding: utf-8
require 'cases/helper'

require 'models/topic'

class ValidatesWithTest < ActiveRecord::TestCase
  include ActiveModel::ValidationsRepairHelper

  repair_validations(Topic)

  ERROR_MESSAGE = "Validation error from validator"
  OTHER_ERROR_MESSAGE = "Validation error from other validator"

  class ValidatorThatAddsErrors < ActiveRecord::Validator
    def validate()
      record.errors[:base] << ERROR_MESSAGE
    end
  end

  class OtherValidatorThatAddsErrors < ActiveRecord::Validator
    def validate()
      record.errors[:base] << OTHER_ERROR_MESSAGE
    end
  end

  class ValidatorThatDoesNotAddErrors < ActiveRecord::Validator
    def validate()
    end
  end

  class ValidatorThatValidatesOptions < ActiveRecord::Validator
    def validate()
      if options[:field] == :first_name
        record.errors[:base] << ERROR_MESSAGE
      end
    end
  end

  test "vaidation with class that adds errors" do
    Topic.validates_with(ValidatorThatAddsErrors)
    topic = Topic.new
    assert !topic.valid?, "A class that adds errors causes the record to be invalid"
    assert topic.errors[:base].include?(ERROR_MESSAGE)
  end

  test "with a class that returns valid" do
    Topic.validates_with(ValidatorThatDoesNotAddErrors)
    topic = Topic.new
    assert topic.valid?, "A class that does not add errors does not cause the record to be invalid"
  end

  test "with a class that adds errors on update and a new record" do
    Topic.validates_with(ValidatorThatAddsErrors, :on => :update)
    topic = Topic.new
    assert topic.valid?, "Validation doesn't run on create if 'on' is set to update"
  end

  test "with a class that adds errors on create and a new record" do
    Topic.validates_with(ValidatorThatAddsErrors, :on => :create)
    topic = Topic.new
    assert !topic.valid?, "Validation does run on create if 'on' is set to create"
    assert topic.errors[:base].include?(ERROR_MESSAGE)
  end

  test "with multiple classes" do
    Topic.validates_with(ValidatorThatAddsErrors, OtherValidatorThatAddsErrors)
    topic = Topic.new
    assert !topic.valid?
    assert topic.errors[:base].include?(ERROR_MESSAGE)
    assert topic.errors[:base].include?(OTHER_ERROR_MESSAGE)
  end

  test "with if statements that return false" do
    Topic.validates_with(ValidatorThatAddsErrors, :if => "1 == 2")
    topic = Topic.new
    assert topic.valid?
  end

  test "with if statements that return true" do
    Topic.validates_with(ValidatorThatAddsErrors, :if => "1 == 1")
    topic = Topic.new
    assert !topic.valid?
    assert topic.errors[:base].include?(ERROR_MESSAGE)
  end

  test "with unless statements that return true" do
    Topic.validates_with(ValidatorThatAddsErrors, :unless => "1 == 1")
    topic = Topic.new
    assert topic.valid?
  end

  test "with unless statements that returns false" do
    Topic.validates_with(ValidatorThatAddsErrors, :unless => "1 == 2")
    topic = Topic.new
    assert !topic.valid?
    assert topic.errors[:base].include?(ERROR_MESSAGE)
  end

  test "passes all non-standard configuration options to the validator class" do
    topic = Topic.new
    validator = mock()
    validator.expects(:new).with(topic, {:foo => :bar}).returns(validator)
    validator.expects(:validate)

    Topic.validates_with(validator, :if => "1 == 1", :foo => :bar)
    assert topic.valid?
  end

  test "validates_with with options" do
    Topic.validates_with(ValidatorThatValidatesOptions, :field => :first_name)
    topic = Topic.new
    assert !topic.valid?
    assert topic.errors[:base].include?(ERROR_MESSAGE)
  end

end
