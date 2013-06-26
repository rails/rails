# encoding: utf-8
require 'cases/helper'
require 'models/topic'
require 'models/person'
require 'models/custom_reader'

class AbsenceValidationTest < ActiveModel::TestCase
  teardown do
    Topic.reset_callbacks(:validate)
    Person.reset_callbacks(:validate)
    CustomReader.reset_callbacks(:validate)
  end

  def test_validate_absences
    Topic.validates_absence_of(:title, :content)
    t = Topic.new
    t.title = "foo"
    t.content = "bar"
    assert t.invalid?
    assert_equal ["must be blank"], t.errors[:title]
    assert_equal ["must be blank"], t.errors[:content]
    t.title = ""
    t.content  = "something"
    assert t.invalid?
    assert_equal ["must be blank"], t.errors[:content]
    t.content = ""
    assert t.valid?
  end

  def test_accepts_array_arguments
    Topic.validates_absence_of %w(title content)
    t = Topic.new
    t.title = "foo"
    t.content = "bar"
    assert t.invalid?
    assert_equal ["must be blank"], t.errors[:title]
    assert_equal ["must be blank"], t.errors[:content]
  end

  def test_validates_acceptance_of_with_custom_error_using_quotes
    Person.validates_absence_of :karma, message: "This string contains 'single' and \"double\" quotes"
    p = Person.new
    p.karma = "good"
    assert p.invalid?
    assert_equal "This string contains 'single' and \"double\" quotes", p.errors[:karma].last
  end

  def test_validates_absence_of_for_ruby_class
    Person.validates_absence_of :karma
    p = Person.new
    p.karma = "good"
    assert p.invalid?
    assert_equal ["must be blank"], p.errors[:karma]
    p.karma = nil
    assert p.valid?
  end

  def test_validates_absence_of_for_ruby_class_with_custom_reader
    CustomReader.validates_absence_of :karma
    p = CustomReader.new
    p[:karma] = "excellent"
    assert p.invalid?
    assert_equal ["must be blank"], p.errors[:karma]
    p[:karma] = ""
    assert p.valid?
  end
end
