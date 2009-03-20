# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'

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
end
