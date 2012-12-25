# encoding: utf-8
require "cases/helper"
require 'models/man'
require 'models/face'
require 'models/interest'

class PresenceValidationTest < ActiveRecord::TestCase
  class Boy < Man; end

  repair_validations(Boy)

  def test_validates_presence_of_non_association
    Boy.validates_presence_of(:name)
    b = Boy.new
    assert b.invalid?

    b.name = "Alex"
    assert b.valid?
  end

  def test_validates_presence_of_has_one
    Boy.validates_presence_of(:face)
    b = Boy.new
    assert b.invalid?, "should not be valid if has_one association missing"
    assert_equal 1, b.errors[:face].size, "validates_presence_of should only add one error"
  end

  def test_validates_presence_of_has_one_marked_for_destruction
    Boy.validates_presence_of(:face)
    b = Boy.new
    f = Face.new
    b.face = f
    assert b.valid?

    f.mark_for_destruction
    assert b.invalid?
  end

  def test_validates_presence_of_has_many_marked_for_destruction
    Boy.validates_presence_of(:interests)
    b = Boy.new
    b.interests << [i1 = Interest.new, i2 = Interest.new]
    assert b.valid?

    i1.mark_for_destruction
    assert b.valid?

    i2.mark_for_destruction
    assert b.invalid?
  end
end
