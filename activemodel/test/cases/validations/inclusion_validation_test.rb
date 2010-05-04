# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/developer'
require 'models/person'

class InclusionValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase

  def teardown
    Topic.reset_callbacks(:validate)
  end

  def test_validates_inclusion_of
    Topic.validates_inclusion_of( :title, :in => %w( a b c d e f g ) )

    assert !Topic.create("title" => "a!", "content" => "abc").valid?
    assert !Topic.create("title" => "a b", "content" => "abc").valid?
    assert !Topic.create("title" => nil, "content" => "def").valid?

    t = Topic.create("title" => "a", "content" => "I know you are but what am I?")
    assert t.valid?
    t.title = "uhoh"
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["is not included in the list"], t.errors[:title]

    assert_raise(ArgumentError) { Topic.validates_inclusion_of( :title, :in => nil ) }
    assert_raise(ArgumentError) { Topic.validates_inclusion_of( :title, :in => 0) }

    assert_nothing_raised(ArgumentError) { Topic.validates_inclusion_of( :title, :in => "hi!" ) }
    assert_nothing_raised(ArgumentError) { Topic.validates_inclusion_of( :title, :in => {} ) }
    assert_nothing_raised(ArgumentError) { Topic.validates_inclusion_of( :title, :in => [] ) }
  end

  def test_validates_inclusion_of_with_allow_nil
    Topic.validates_inclusion_of( :title, :in => %w( a b c d e f g ), :allow_nil=>true )

    assert !Topic.create("title" => "a!", "content" => "abc").valid?
    assert !Topic.create("title" => "", "content" => "abc").valid?
    assert Topic.create("title" => nil, "content" => "abc").valid?
  end

  def test_validates_inclusion_of_with_formatted_message
    Topic.validates_inclusion_of( :title, :in => %w( a b c d e f g ), :message => "option %{value} is not in the list" )

    assert Topic.create("title" => "a", "content" => "abc").valid?

    t = Topic.create("title" => "uhoh", "content" => "abc")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["option uhoh is not in the list"], t.errors[:title]
  end

  def test_validates_inclusion_of_for_ruby_class
    Person.validates_inclusion_of :karma, :in => %w( abe monkey )

    p = Person.new
    p.karma = "Lifo"
    assert p.invalid?

    assert_equal ["is not included in the list"], p.errors[:karma]

    p.karma = "monkey"
    assert p.valid?
  ensure
    Person.reset_callbacks(:validate)
  end
end
