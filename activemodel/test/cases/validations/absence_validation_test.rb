# frozen_string_literal: true

require 'cases/helper'
require 'models/topic'
require 'models/person'
require 'models/custom_reader'

class AbsenceValidationTest < ActiveModel::TestCase
  teardown do
    Topic.clear_validators!
    Person.clear_validators!
    CustomReader.clear_validators!
  end

  def test_validates_absence_of
    Topic.validates_absence_of(:title, :content)
    t = Topic.new
    t.title = 'foo'
    t.content = 'bar'
    assert_predicate t, :invalid?
    assert_equal ['must be blank'], t.errors[:title]
    assert_equal ['must be blank'], t.errors[:content]
    t.title = ''
    t.content = 'something'
    assert_predicate t, :invalid?
    assert_equal ['must be blank'], t.errors[:content]
    assert_equal [], t.errors[:title]
    t.content = ''
    assert_predicate t, :valid?
  end

  def test_validates_absence_of_with_array_arguments
    Topic.validates_absence_of %w(title content)
    t = Topic.new
    t.title = 'foo'
    t.content = 'bar'
    assert_predicate t, :invalid?
    assert_equal ['must be blank'], t.errors[:title]
    assert_equal ['must be blank'], t.errors[:content]
  end

  def test_validates_absence_of_with_custom_error_using_quotes
    Person.validates_absence_of :karma, message: "This string contains 'single' and \"double\" quotes"
    p = Person.new
    p.karma = 'good'
    assert_predicate p, :invalid?
    assert_equal "This string contains 'single' and \"double\" quotes", p.errors[:karma].last
  end

  def test_validates_absence_of_for_ruby_class
    Person.validates_absence_of :karma
    p = Person.new
    p.karma = 'good'
    assert_predicate p, :invalid?
    assert_equal ['must be blank'], p.errors[:karma]
    p.karma = nil
    assert_predicate p, :valid?
  end

  def test_validates_absence_of_for_ruby_class_with_custom_reader
    CustomReader.validates_absence_of :karma
    p = CustomReader.new
    p[:karma] = 'excellent'
    assert_predicate p, :invalid?
    assert_equal ['must be blank'], p.errors[:karma]
    p[:karma] = ''
    assert_predicate p, :valid?
  end
end
