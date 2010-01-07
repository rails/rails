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
  end

  def test_validates_with_built_in_validation
    Person.validates :title, :numericality => true
    person = Person.new
    person.valid?
    assert person.errors[:title].include?('is not a number')
  end

  def test_validates_with_built_in_validation_and_options
    Person.validates :title, :numericality => { :message => 'my custom message' }
    person = Person.new
    person.valid?
    assert person.errors[:title].include?('my custom message')
  end
  
  def test_validates_with_validator_class
    Person.validates :karma, :email => true
    person = Person.new
    person.valid?
    assert person.errors[:karma].include?('is not an email')
  end

  def test_validates_with_if_as_local_conditions
    Person.validates :karma, :presence => true, :email => { :unless => :condition_is_true }
    person = Person.new
    person.valid?
    assert !person.errors[:karma].include?('is not an email')
    assert person.errors[:karma].include?('can\'t be blank')
  end

  def test_validates_with_if_as_shared_conditions
    Person.validates :karma, :presence => true, :email => true, :if => :condition_is_true
    person = Person.new
    person.valid?
    assert person.errors[:karma].include?('is not an email')
    assert person.errors[:karma].include?('can\'t be blank')
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

  def test_validates_with_validator_class_and_options
    Person.validates :karma, :email => { :message => 'my custom message' }
    person = Person.new
    person.valid?
    assert person.errors[:karma].include?('my custom message')
  end
  
  def test_validates_with_unknown_validator
    assert_raise(ArgumentError) { Person.validates :karma, :unknown => true }
  end
  
  def test_validates_with_included_validator
    PersonWithValidator.validates :title, :presence => true
    person = PersonWithValidator.new
    person.valid?
    assert person.errors[:title].include?('Local validator')
  end
  
  def test_validates_with_included_validator_and_options
    PersonWithValidator.validates :title, :presence => { :custom => ' please' }
    person = PersonWithValidator.new
    person.valid?
    assert person.errors[:title].include?('Local validator please')
  end
end