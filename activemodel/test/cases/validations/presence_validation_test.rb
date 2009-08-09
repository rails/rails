# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/developer'
require 'models/person'

class PresenceValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase
  include ActiveModel::ValidationsRepairHelper

  repair_validations(Topic)

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

  # def test_validates_presence_of_with_custom_message_using_quotes
  #   repair_validations(Developer) do
  #     Developer.validates_presence_of :non_existent, :message=> "This string contains 'single' and \"double\" quotes"
  #     d = Developer.new
  #     d.name = "Joe"
  #     assert !d.valid?
  #     assert_equal ["This string contains 'single' and \"double\" quotes"], d.errors[:non_existent]
  #   end
  # end

  def test_validates_presence_of_for_ruby_class
    repair_validations(Person) do
      Person.validates_presence_of :karma

      p = Person.new
      assert p.invalid?

      assert_equal ["can't be blank"], p.errors[:karma]

      p.karma = "Cold"
      assert p.valid?
    end
  end
  
  def test_validates_presence_of_for_ruby_class_with_custom_reader
    repair_validations(Person) do
      CustomReader.validates_presence_of :karma

      p = CustomReader.new
      assert p.invalid?

      assert_equal ["can't be blank"], p.errors[:karma]

      p[:karma] = "Cold"
      assert p.valid?
    end
  end
end
