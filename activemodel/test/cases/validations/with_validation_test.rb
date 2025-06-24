# frozen_string_literal: true

require "cases/helper"

require "models/topic"

class ValidatesWithTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  ERROR_MESSAGE = "Validation error from validator"
  OTHER_ERROR_MESSAGE = "Validation error from other validator"

  class ValidatorThatAddsErrors < ActiveModel::Validator
    def validate(record)
      record.errors.add(:base, message: ERROR_MESSAGE)
    end
  end

  class OtherValidatorThatAddsErrors < ActiveModel::Validator
    def validate(record)
      record.errors.add(:base, message: OTHER_ERROR_MESSAGE)
    end
  end

  class ValidatorThatDoesNotAddErrors < ActiveModel::Validator
    def validate(record)
    end
  end

  class ValidatorThatClearsOptions < ValidatorThatDoesNotAddErrors
    def initialize(options)
      super
      options.clear
    end
  end

  class ValidatorThatValidatesOptions < ActiveModel::Validator
    def validate(record)
      if options[:field] == :first_name
        record.errors.add(:base, message: ERROR_MESSAGE)
      end
    end
  end

  class ValidatorPerEachAttribute < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add(attribute, message: "Value is #{value}")
    end
  end

  class ValidatorCheckValidity < ActiveModel::EachValidator
    def check_validity!
      raise "boom!"
    end
  end

  test "validation with class that adds errors" do
    Topic.validates_with(ValidatorThatAddsErrors)
    topic = Topic.new
    assert_predicate topic, :invalid?, "A class that adds errors causes the record to be invalid"
    assert_includes topic.errors[:base], ERROR_MESSAGE
  end

  test "with a class that returns valid" do
    Topic.validates_with(ValidatorThatDoesNotAddErrors)
    topic = Topic.new
    assert_predicate topic, :valid?, "A class that does not add errors does not cause the record to be invalid"
  end

  test "with multiple classes" do
    Topic.validates_with(ValidatorThatAddsErrors, OtherValidatorThatAddsErrors)
    topic = Topic.new
    assert_predicate topic, :invalid?
    assert_includes topic.errors[:base], ERROR_MESSAGE
    assert_includes topic.errors[:base], OTHER_ERROR_MESSAGE
  end

  test "passes all configuration options to the validator class" do
    topic = Topic.new
    validator = Minitest::Mock.new
    validator.expect(:new, validator, [{ foo: :bar, if: :condition_is_true, class: Topic }])
    validator.expect(:validate, nil, [topic])
    validator.expect(:is_a?, false, [String]) # Call run by ActiveSupport::Callbacks::Callback.build

    Topic.validates_with(validator, if: :condition_is_true, foo: :bar)
    assert_predicate topic, :valid?
    validator.verify
  end

  test "validates_with with options" do
    Topic.validates_with(ValidatorThatValidatesOptions, field: :first_name)
    topic = Topic.new
    assert_predicate topic, :invalid?
    assert_includes topic.errors[:base], ERROR_MESSAGE
  end

  test "validates_with preserves standard options" do
    Topic.validates_with(ValidatorThatClearsOptions, ValidatorThatAddsErrors, on: :specific_context)
    topic = Topic.new
    assert topic.invalid?(:specific_context), "validation should work"
    assert_predicate topic, :valid?, "Standard options should be preserved"
  end

  test "validates_with preserves validator options" do
    Topic.validates_with(ValidatorThatClearsOptions, ValidatorThatValidatesOptions, field: :first_name)
    topic = Topic.new
    assert_predicate topic, :invalid?, "Validator options should be preserved"
  end

  test "instance validates_with method preserves validator options" do
    topic = Topic.new
    topic.validates_with(ValidatorThatClearsOptions, ValidatorThatValidatesOptions, field: :first_name)
    assert_includes topic.errors[:base], ERROR_MESSAGE, "Validator options should be preserved"
  end

  test "validates_with each validator" do
    Topic.validates_with(ValidatorPerEachAttribute, attributes: [:title, :content])
    topic = Topic.new title: "Title", content: "Content"
    assert_predicate topic, :invalid?
    assert_equal ["Value is Title"], topic.errors[:title]
    assert_equal ["Value is Content"], topic.errors[:content]
  end

  test "each validator checks validity" do
    assert_raise RuntimeError do
      Topic.validates_with(ValidatorCheckValidity, attributes: [:title])
    end
  end

  test "each validator expects attributes to be given" do
    assert_raise ArgumentError do
      Topic.validates_with(ValidatorPerEachAttribute)
    end
  end

  test "each validator skip nil values if :allow_nil is set to true" do
    Topic.validates_with(ValidatorPerEachAttribute, attributes: [:title, :content], allow_nil: true)
    topic = Topic.new content: ""
    assert_predicate topic, :invalid?
    assert_empty topic.errors[:title]
    assert_equal ["Value is "], topic.errors[:content]
  end

  test "each validator skip blank values if :allow_blank is set to true" do
    Topic.validates_with(ValidatorPerEachAttribute, attributes: [:title, :content], allow_blank: true)
    topic = Topic.new content: ""
    assert_predicate topic, :valid?
    assert_empty topic.errors[:title]
    assert_empty topic.errors[:content]
  end

  test "validates_with can validate with an instance method" do
    Topic.validates :title, with: :my_validation

    topic = Topic.new title: "foo"
    assert_predicate topic, :valid?
    assert_empty topic.errors[:title]

    topic = Topic.new
    assert_not_predicate topic, :valid?
    assert_equal ["is missing"], topic.errors[:title]
  end

  test "optionally pass in the attribute being validated when validating with an instance method" do
    Topic.validates :title, :content, with: :my_validation_with_arg

    topic = Topic.new title: "foo"
    assert_not_predicate topic, :valid?
    assert_empty topic.errors[:title]
    assert_equal ["is missing"], topic.errors[:content]
  end
end
