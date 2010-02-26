# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/developer'
require 'models/person'
require 'models/custom_reader'

class PresenceValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase

  teardown do
    Topic.reset_callbacks(:validate)
    Person.reset_callbacks(:validate)
    CustomReader.reset_callbacks(:validate)
  end

  def test_validate_presences
    Topic.validates_presence_of(:title, :content)

    t = Topic.create
    assert !t.save
    assert_equal ["can't be blank"], t.errors[:title]
    assert_equal ["can't be blank"], t.errors[:content]

    t.title = "something"
    t.content  = "   "

    assert !t.save
    assert_equal ["can't be blank"], t.errors[:content]

    t.content = "like stuff"

    assert t.save
  end

  test 'accepts array arguments' do
    Topic.validates_presence_of %w(title content)
    t = Topic.new
    assert !t.valid?
    assert_equal ["can't be blank"], t.errors[:title]
    assert_equal ["can't be blank"], t.errors[:content]
  end

  def test_validates_acceptance_of_with_custom_error_using_quotes
    Person.validates_presence_of :karma, :message => "This string contains 'single' and \"double\" quotes"
    p = Person.new
    assert !p.valid?
    assert_equal "This string contains 'single' and \"double\" quotes", p.errors[:karma].last
  end

  def test_validates_presence_of_for_ruby_class
    Person.validates_presence_of :karma

    p = Person.new
    assert p.invalid?

    assert_equal ["can't be blank"], p.errors[:karma]

    p.karma = "Cold"
    assert p.valid?
  end

  def test_validates_presence_of_for_ruby_class_with_custom_reader
    CustomReader.validates_presence_of :karma

    p = CustomReader.new
    assert p.invalid?

    assert_equal ["can't be blank"], p.errors[:karma]

    p[:karma] = "Cold"
    assert p.valid?
  end
end
