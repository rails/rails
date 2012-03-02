# encoding: utf-8
require 'cases/helper'

require 'models/person'

class SubsetValidationTest < ActiveModel::TestCase

  def teardown
    Person.reset_callbacks(:validate)
  end

  def test_validates_subset_of
    nicknames = ['Bubba', 'Jimbo', 'Jr.', 'Rodney', 'Edmundo']

    Person.validates_subset_of(:nicknames, :in => nicknames)

    assert Person.new(:nicknames => "blargle").invalid?
    assert Person.new(:nicknames => ["blargle"]).invalid?
    assert Person.new(:nicknames => nicknames + ["blargle"]).invalid?
    assert Person.new(:nicknames => nicknames.sample(nicknames.length - 1) + ["blargle"]).invalid?

    (1..nicknames.length).each do |i|
      assert Person.new(:nicknames => nicknames.sample(i)).valid?
    end
  end

  def test_validates_subset_of_with_allow_nil
    nicknames = ['Bubba', 'Jimbo', 'Jr.', 'Rodney', 'Edmundo']

    Person.validates_subset_of(:nicknames, :in => nicknames, :allow_nil => true)

    assert Person.new(:nicknames => nil).valid?

    Person.reset_callbacks(:validate)

    Person.validates_subset_of(:nicknames, :in => nicknames, :allow_nil => false)

    assert Person.new(:nicknames => nil).invalid?

    Person.reset_callbacks(:validate)

    Person.validates_subset_of(:nicknames, :in => nicknames)

    assert Person.new(:nicknames => nil).invalid?
  end

  def test_validates_subset_of_with_allow_blank
    nicknames = ['Bubba', 'Jimbo', 'Jr.', 'Rodney', 'Edmundo']

    Person.validates_subset_of(:nicknames, :in => nicknames, :allow_blank => true)

    assert Person.new(:nicknames => nil).valid?
    assert Person.new(:nicknames => "").valid?
    assert Person.new(:nicknames => []).valid?

    Person.reset_callbacks(:validate)

    Person.validates_subset_of(:nicknames, :in => nicknames, :allow_blank => false)

    assert Person.new(:nicknames => nil).invalid?
    assert Person.new(:nicknames => "").invalid?
    assert Person.new(:nicknames => []).invalid?

    Person.reset_callbacks(:validate)

    Person.validates_subset_of(:nicknames, :in => nicknames)

    assert Person.new(:nicknames => nil).invalid?
    assert Person.new(:nicknames => "").invalid?
    assert Person.new(:nicknames => []).invalid?
  end

  def test_validates_subset_of_with_default_message
    Person.validates_subset_of(:nicknames, :in => ['Bubba', 'Jimbo', 'Jr.', 'Rodney', 'Edmundo'])

    nicknames = ["Bubbajim"]
    p = Person.new(:nicknames => nicknames)

    assert p.invalid?
    assert_equal ["is not a subset of the list"], p.errors[:nicknames]
  end

  def test_validates_subset_of_with_formatted_message
    Person.validates_subset_of(:nicknames, :in => ['Bubba', 'Jimbo', 'Jr.', 'Rodney', 'Edmundo'], :message => "%{value} ain't a subset")

    nicknames = ["Bubbajim"]
    p = Person.new(:nicknames => nicknames)

    assert p.invalid?
    assert_equal ["#{nicknames} ain't a subset"], p.errors[:nicknames]
  end

  def test_validates_subset_of_with_lambda
    Person.validates_subset_of :nicknames, :in => lambda{ |p| p.title == "Duke of Rodney" ? ["Rodney", "Duke"] : ["Edmundo", "Sir"] }

    p = Person.new
    p.title = "Duke of Rodney"

    p.nicknames = ["Sir"]
    assert p.invalid?
    p.nicknames = ["Edmundo"]
    assert p.invalid?
    p.nicknames = ["Sir", "Edmundo"]
    assert p.invalid?

    p.nicknames = ["Rodney"]
    assert p.valid?
    p.nicknames = ["Duke"]
    assert p.valid?
    p.nicknames = ["Rodney", "Duke"]
    assert p.valid?

    p.title = "Sir Edmundo"

    p.nicknames = ["Rodney"]
    assert p.invalid?
    p.nicknames = ["Duke"]
    assert p.invalid?
    p.nicknames = ["Rodney", "Duke"]
    assert p.invalid?

    p.nicknames = ["Sir"]
    assert p.valid?
    p.nicknames = ["Edmundo"]
    assert p.valid?
    p.nicknames = ["Sir", "Edmundo"]
    assert p.valid?
  end

  def test_argument_validation
    assert_raise(ArgumentError) { Person.validates_subset_of(:nicknames, :in => nil ) }
    assert_raise(ArgumentError) { Person.validates_subset_of(:nicknames, :in => 0) }
  end
end