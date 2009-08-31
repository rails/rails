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

  def test_validate_format
    Topic.validates_format_of(:title, :content, :with => /^Validation\smacros \w+!$/, :message => "is bad data")

    t = Topic.create("title" => "i'm incorrect", "content" => "Validation macros rule!")
    assert !t.valid?, "Shouldn't be valid"
    assert !t.save, "Shouldn't save because it's invalid"
    assert_equal ["is bad data"], t.errors[:title]
    assert t.errors[:content].empty?

    t.title = "Validation macros rule!"

    assert t.save
    assert t.errors[:title].empty?

    assert_raise(ArgumentError) { Topic.validates_format_of(:title, :content) }
  end

  def test_validate_format_with_allow_blank
    Topic.validates_format_of(:title, :with => /^Validation\smacros \w+!$/, :allow_blank=>true)
    assert !Topic.create("title" => "Shouldn't be valid").valid?
    assert Topic.create("title" => "").valid?
    assert Topic.create("title" => nil).valid?
    assert Topic.create("title" => "Validation macros rule!").valid?
  end

  # testing ticket #3142
  def test_validate_format_numeric
    Topic.validates_format_of(:title, :content, :with => /^[1-9][0-9]*$/, :message => "is bad data")

    t = Topic.create("title" => "72x", "content" => "6789")
    assert !t.valid?, "Shouldn't be valid"
    assert !t.save, "Shouldn't save because it's invalid"
    assert_equal ["is bad data"], t.errors[:title]
    assert t.errors[:content].empty?

    t.title = "-11"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "03"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "z44"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "5v7"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "1"

    assert t.save
    assert t.errors[:title].empty?
  end

  def test_validate_format_with_formatted_message
    Topic.validates_format_of(:title, :with => /^Valid Title$/, :message => "can't be {{value}}")
    t = Topic.create(:title => 'Invalid title')
    assert_equal ["can't be Invalid title"], t.errors[:title]
  end

  def test_validate_format_with_not_option
    Topic.validates_format_of(:title, :without => /foo/, :message => "should not contain foo")
    t = Topic.new

    t.title = "foobar"
    t.valid?
    assert_equal ["should not contain foo"], t.errors[:title]

    t.title = "something else"
    t.valid?
    assert_equal [], t.errors[:title]
  end

  def test_validate_format_of_without_any_regexp_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title) }
  end

  def test_validates_format_of_with_both_regexps_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title, :with => /this/, :without => /that/) }
  end

  def test_validates_format_of_when_with_isnt_a_regexp_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title, :with => "clearly not a regexp") }
  end

  def test_validates_format_of_when_not_isnt_a_regexp_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title, :without => "clearly not a regexp") }
  end

  def test_validates_format_of_with_custom_error_using_quotes
    repair_validations(Developer) do
      Developer.validates_format_of :name, :with => /^(A-Z*)$/, :message=> "format 'single' and \"double\" quotes"
      d = Developer.new
      d.name = d.name_confirmation = "John 32"
      assert !d.valid?
      assert_equal ["format 'single' and \"double\" quotes"], d.errors[:name]
    end
  end

  def test_validates_format_of_for_ruby_class
    repair_validations(Person) do
      Person.validates_format_of :karma, :with => /\A\d+\Z/

      p = Person.new
      p.karma = "Pixies"
      assert p.invalid?

      assert_equal ["is invalid"], p.errors[:karma]

      p.karma = "1234"
      assert p.valid?
    end
  end
end
