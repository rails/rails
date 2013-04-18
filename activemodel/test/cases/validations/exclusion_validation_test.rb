# encoding: utf-8
require 'cases/helper'

require 'models/topic'
require 'models/person'

class ExclusionValidationTest < ActiveModel::TestCase

  def teardown
    Topic.reset_callbacks(:validate)
  end

  def test_validates_exclusion_of_range_on_array_attribute
    Topic.validates_exclusion_of(:aliases, :in => 1...3)
    assert Topic.new("aliases" => [ 1 ]).invalid?
    assert Topic.new("aliases" => [ 1, 5, 9 ]).invalid?
    assert Topic.new("aliases" => [ 4, 5, 9 ]).valid?
  end

  def test_validates_exclusion_of_values_on_array_attribute
    Topic.validates_exclusion_of(:aliases, :in => [ 1, 2, 3 ])
    assert Topic.new("aliases" => [ 1 ]).invalid?
    assert Topic.new("aliases" => [ 1, 5, 9 ]).invalid?
    assert Topic.new("aliases" => [ 4, 5, 9 ]).valid?
  end

  def test_validates_exclusion_of_array_attribute_with_allow_nil
    Topic.validates_exclusion_of(:aliases, :in => [ 1, 2, 3 ], :allow_nil => true)
    assert Topic.new("aliases" => [ 1 ]).invalid?
    assert Topic.new("aliases" => [ 4, 5, 9 ]).valid?
    assert Topic.new.valid?
  end

  def test_validates_exclusion_of_array_attribute_with_allow_blank
    Topic.validates_exclusion_of(:aliases, :in => [ 1, 2, 3 ], :allow_blank => true)
    assert Topic.new("aliases" => [ 1 ]).invalid?
    assert Topic.new("aliases" => [ 4, 5, 9 ]).valid?
    assert Topic.new("aliases" => []).valid?
  end

  def test_validates_exclusion_of
    Topic.validates_exclusion_of( :title, :in => %w( abe monkey ) )

    assert Topic.new("title" => "something", "content" => "abc").valid?
    assert Topic.new("title" => "monkey", "content" => "abc").invalid?
  end

  def test_validates_exclusion_of_with_formatted_message
    Topic.validates_exclusion_of( :title, :in => %w( abe monkey ), :message => "option %{value} is restricted" )

    assert Topic.new("title" => "something", "content" => "abc")

    t = Topic.new("title" => "monkey")
    assert t.invalid?
    assert t.errors[:title].any?
    assert_equal ["option monkey is restricted"], t.errors[:title]
  end

  def test_validates_exclusion_of_with_within_option
    Topic.validates_exclusion_of( :title, :within => %w( abe monkey ) )

    assert Topic.new("title" => "something", "content" => "abc")

    t = Topic.new("title" => "monkey")
    assert t.invalid?
    assert t.errors[:title].any?
  end

  def test_validates_exclusion_of_for_ruby_class
    Person.validates_exclusion_of :karma, :in => %w( abe monkey )

    p = Person.new
    p.karma = "abe"
    assert p.invalid?

    assert_equal ["is (or has a value that is) reserved"], p.errors[:karma]

    p.karma = "Lifo"
    assert p.valid?
  ensure
    Person.reset_callbacks(:validate)
  end

  def test_validates_exclusion_of_with_lambda
    Topic.validates_exclusion_of :title, :in => lambda{ |topic| topic.author_name == "sikachu" ? %w( monkey elephant ) : %w( abe wasabi ) }

    t = Topic.new
    t.title = "elephant"
    t.author_name = "sikachu"
    assert t.invalid?

    t.title = "wasabi"
    assert t.valid?
  end

  def test_validates_inclusion_of_with_symbol
    Person.validates_exclusion_of :karma, :in => :reserved_karmas

    p = Person.new
    p.karma = "abe"

    def p.reserved_karmas
      %w(abe)
    end

    assert p.invalid?
    assert_equal ["is (or has a value that is) reserved"], p.errors[:karma]

    p = Person.new
    p.karma = "abe"

    def p.reserved_karmas
      %w()
    end

    assert p.valid?
  ensure
    Person.reset_callbacks(:validate)
  end
end
