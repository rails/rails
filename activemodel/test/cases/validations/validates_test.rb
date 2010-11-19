# encoding: utf-8
require 'cases/helper'
require 'models/person'
require 'models/person_with_validator'
require 'validators/email_validator'

class ValidatesTest < ActiveModel::TestCase
  setup :reset_callbacks
  teardown :reset_callbacks

  def reset_callbacks
    Person.reset_callbacks(:validate)
    PersonWithValidator.reset_callbacks(:validate)
  end

  def test_validates_with_built_in_validation
    Person.validates :title, :numericality => true
    person = Person.new
    person.valid?
    assert_equal ['is not a number'], person.errors[:title]
  end

  def test_validates_with_built_in_validation_and_options
    Person.validates :salary, :numericality => { :message => 'my custom message' }
    person = Person.new
    person.valid?
    assert_equal ['my custom message'], person.errors[:salary]
  end

  def test_validates_with_validator_class
    Person.validates :karma, :email => true
    person = Person.new
    person.valid?
    assert_equal ['is not an email'], person.errors[:karma]
  end

  def test_validates_with_if_as_local_conditions
    Person.validates :karma, :presence => true, :email => { :unless => :condition_is_true }
    person = Person.new
    person.valid?
    assert_equal ["can't be blank"], person.errors[:karma]
  end

  def test_validates_with_if_as_shared_conditions
    Person.validates :karma, :presence => true, :email => true, :if => :condition_is_true
    person = Person.new
    person.valid?
    assert_equal ["can't be blank", "is not an email"], person.errors[:karma].sort
  end

  def test_validates_with_unless_shared_conditions
    Person.validates :karma, :presence => true, :email => true, :unless => :condition_is_true
    person = Person.new
    assert person.valid?
  end

  def test_validates_with_allow_nil_shared_conditions
    Person.validates :karma, :length => { :minimum => 20 }, :email => true, :allow_nil => true
    person = Person.new
    assert person.valid?
  end

  def test_validates_raises_error_on_invalid_option
    assert_raises ArgumentError do
      Person.validates :karma, :length => 5
    end
  end

  def test_validates_with_regexp
    Person.validates :karma, :format => /positive|negative/
    person = Person.new
    assert person.invalid?
    assert_equal ['is invalid'], person.errors[:karma]
    person.karma = "positive"
    assert person.valid?
  end

  def test_validates_with_array
    Person.validates :gender, :inclusion => %w(m f)
    person = Person.new
    assert person.invalid?
    assert_equal ['is not included in the list'], person.errors[:gender]
    person.gender = "m"
    assert person.valid?
  end

  def test_validates_with_range
    Person.validates :karma, :length => 6..20
    person = Person.new
    assert person.invalid?
    assert_equal ['is too short (minimum is 6 characters)'], person.errors[:karma]
    person.karma = 'something'
    assert person.valid?
  end

  def test_validates_with_validator_class_and_options
    Person.validates :karma, :email => { :message => 'my custom message' }
    person = Person.new
    person.valid?
    assert_equal ['my custom message'], person.errors[:karma]
  end

  def test_validates_with_unknown_validator
    assert_raise(ArgumentError) { Person.validates :karma, :unknown => true }
  end

  def test_validates_with_included_validator
    PersonWithValidator.validates :title, :presence => true
    person = PersonWithValidator.new
    person.valid?
    assert_equal ['Local validator'], person.errors[:title]
  end

  def test_validates_with_included_validator_and_options
    PersonWithValidator.validates :title, :presence => { :custom => ' please' }
    person = PersonWithValidator.new
    person.valid?
    assert_equal ['Local validator please'], person.errors[:title]
  end
end
