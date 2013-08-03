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

  class Topic < ActiveRecord::Base
    self.table_name = "topics"
    validates_presence_of :title, on: :save
  end

  class PresenceValidationTestWithOnSaveOption < ActiveRecord::TestCase
    fixtures :topics
  
    def test_validate_presence_when_object_is_new
      topic = Topic.create
      assert topic.invalid?, "The object is invalid due to blank value of title"
      assert_includes topic.errors.messages, :title
      assert_equal ["can't be blank"], topic.errors.messages[:title]
    end

    def test_validate_presence_when_object_is_already_created
      topic = Topic.create title: 'testing'
      assert topic.valid?

      topic.title = nil
      assert topic.invalid?, "The object is invalid due to blank value of title"
      assert_equal ["Title can't be blank"], topic.errors.full_messages
    end
  end
end
