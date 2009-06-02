# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/person'

class ExclusionValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase
  include ActiveModel::ValidationsRepairHelper

  repair_validations(Topic)

  def test_validates_exclusion_of
    Topic.validates_exclusion_of( :title, :in => %w( abe monkey ) )

    assert Topic.create("title" => "something", "content" => "abc").valid?
    assert !Topic.create("title" => "monkey", "content" => "abc").valid?
  end

  def test_validates_exclusion_of_with_formatted_message
    Topic.validates_exclusion_of( :title, :in => %w( abe monkey ), :message => "option {{value}} is restricted" )

    assert Topic.create("title" => "something", "content" => "abc")

    t = Topic.create("title" => "monkey")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["option monkey is restricted"], t.errors[:title]
  end

  def test_validates_exclusion_of_for_ruby_class
    repair_validations(Person) do
      Person.validates_exclusion_of :karma, :in => %w( abe monkey )

      p = Person.new
      p.karma = "abe"
      assert p.invalid?

      assert_equal ["is reserved"], p.errors[:karma]

      p.karma = "Lifo"
      assert p.valid?
    end
  end
end
