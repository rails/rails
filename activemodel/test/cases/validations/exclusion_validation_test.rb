# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/numeric/time"

require "models/topic"
require "models/person"

class ExclusionValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  def test_validates_exclusion_of
    Topic.validates_exclusion_of(:title, in: %w( abe monkey ))

    assert_predicate Topic.new("title" => "something", "content" => "abc"), :valid?
    assert_predicate Topic.new("title" => "monkey", "content" => "abc"), :invalid?
  end

  def test_validates_exclusion_of_with_formatted_message
    Topic.validates_exclusion_of(:title, in: %w( abe monkey ), message: "option %{value} is restricted")

    assert Topic.new("title" => "something", "content" => "abc")

    t = Topic.new("title" => "monkey")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["option monkey is restricted"], t.errors[:title]
  end

  def test_validates_exclusion_of_with_within_option
    Topic.validates_exclusion_of(:title, within: %w( abe monkey ))

    assert Topic.new("title" => "something", "content" => "abc")

    t = Topic.new("title" => "monkey")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
  end

  def test_validates_exclusion_of_for_ruby_class
    Person.validates_exclusion_of :karma, in: %w( abe monkey )

    p = Person.new
    p.karma = "abe"
    assert_predicate p, :invalid?

    assert_equal ["is reserved"], p.errors[:karma]

    p.karma = "Lifo"
    assert_predicate p, :valid?
  ensure
    Person.clear_validators!
  end

  def test_validates_exclusion_of_with_lambda
    Topic.validates_exclusion_of :title, in: lambda { |topic| topic.author_name == "sikachu" ? %w( monkey elephant ) : %w( abe wasabi ) }

    t = Topic.new
    t.title = "elephant"
    t.author_name = "sikachu"
    assert_predicate t, :invalid?

    t.title = "wasabi"
    assert_predicate t, :valid?
  end

  def test_validates_exclusion_of_with_lambda_without_arguments
    Topic.validates_exclusion_of :title, in: lambda { %w( monkey elephant ) }

    t = Topic.new
    t.title = "monkey"
    assert_predicate t, :invalid?

    t.title = "wasabi"
    assert_predicate t, :valid?
  end

  def test_validates_exclusion_of_with_range
    Topic.validates_exclusion_of :content, in: ("a".."g")

    assert_predicate Topic.new(content: "g"), :invalid?
    assert_predicate Topic.new(content: "h"), :valid?
  end

  def test_validates_exclusion_of_beginless_numeric_range
    range_end = 1000
    Topic.validates_exclusion_of(:raw_price, in: ..range_end)
    assert_predicate Topic.new(title: "aaa", price: -100), :invalid?
    assert_predicate Topic.new(title: "aaa", price: 0), :invalid?
    assert_predicate Topic.new(title: "aaa", price: 100), :invalid?
    assert_predicate Topic.new(title: "aaa", price: 2000), :valid?
    assert_predicate Topic.new(title: "aaa", price: range_end), :invalid?
  end

  def test_validates_exclusion_of_endless_numeric_range
    range_begin = 0
    Topic.validates_exclusion_of(:raw_price, in: range_begin..)
    assert_predicate Topic.new(title: "aaa", price: -1), :valid?
    assert_predicate Topic.new(title: "aaa", price: -100), :valid?
    assert_predicate Topic.new(title: "aaa", price: 100), :invalid?
    assert_predicate Topic.new(title: "aaa", price: 2000), :invalid?
    assert_predicate Topic.new(title: "aaa", price: range_begin), :invalid?
  end

  def test_validates_exclusion_of_with_time_range
    Topic.validates_exclusion_of :created_at, in: 6.days.ago..2.days.ago

    assert_predicate Topic.new(created_at: 5.days.ago), :invalid?
    assert_predicate Topic.new(created_at: 3.days.ago), :invalid?
    assert_predicate Topic.new(created_at: 7.days.ago), :valid?
    assert_predicate Topic.new(created_at: 1.day.ago), :valid?
  end

  def test_validates_inclusion_of_with_symbol
    Person.validates_exclusion_of :karma, in: :reserved_karmas

    p = Person.new
    p.karma = "abe"

    def p.reserved_karmas
      %w(abe)
    end

    assert_predicate p, :invalid?
    assert_equal ["is reserved"], p.errors[:karma]

    p = Person.new
    p.karma = "abe"

    def p.reserved_karmas
      %w()
    end

    assert_predicate p, :valid?
  ensure
    Person.clear_validators!
  end
end
