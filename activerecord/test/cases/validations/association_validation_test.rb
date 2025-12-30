# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"
require "models/human"
require "models/interest"

class AssociationValidationTest < ActiveRecord::TestCase
  fixtures :topics

  repair_validations(Topic, Reply)

  def test_validates_associated_many
    Topic.validates_associated(:replies)
    Reply.validates_presence_of(:content)
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    t.replies << [r = Reply.new("title" => "A reply"), r2 = Reply.new("title" => "Another reply", "content" => "non-empty"), r3 = Reply.new("title" => "Yet another reply"), r4 = Reply.new("title" => "The last reply", "content" => "non-empty")]
    assert_not_predicate t, :valid?
    assert_predicate t.errors[:replies], :any?
    assert_equal 1, r.errors.count  # make sure all associated objects have been validated
    assert_equal 0, r2.errors.count
    assert_equal 1, r3.errors.count
    assert_equal 0, r4.errors.count
    r.content = r3.content = "non-empty"
    assert_predicate t, :valid?
  end

  def test_validates_associated_one
    Reply.validates :topic, associated: true
    Topic.validates_presence_of(:content)
    r = Reply.new("title" => "A reply", "content" => "with content!")
    r.topic = Topic.create("title" => "uhohuhoh")
    assert_not_predicate r, :valid?
    assert_predicate r.errors[:topic], :any?
    r.topic.content = "non-empty"
    assert_predicate r, :valid?
  end

  def test_validates_associated_marked_for_destruction
    Topic.validates_associated(:replies)
    Reply.validates_presence_of(:content)
    t = Topic.new
    t.replies << Reply.new
    assert_predicate t, :invalid?
    t.replies.first.mark_for_destruction
    assert_predicate t, :valid?
  end

  def test_validates_associated_without_marked_for_destruction
    reply = Class.new do
      def valid?(context = nil)
        true
      end
    end
    Topic.validates_associated(:replies)
    t = Topic.new
    t.define_singleton_method(:replies) { [reply.new] }
    assert_predicate t, :valid?
  end

  def test_validates_associated_with_custom_message_using_quotes
    Reply.validates_associated :topic, message: "This string contains 'single' and \"double\" quotes"
    Topic.validates_presence_of :content
    r = Reply.create("title" => "A reply", "content" => "with content!")
    r.topic = Topic.create("title" => "uhohuhoh")
    assert_not_operator r, :valid?
    assert_equal ["This string contains 'single' and \"double\" quotes"], r.errors[:topic]
  end

  def test_validates_associated_missing
    Reply.validates_presence_of(:topic)
    r = Reply.create("title" => "A reply", "content" => "with content!")
    assert_not_predicate r, :valid?
    assert_predicate r.errors[:topic], :any?

    r.topic = Topic.first
    assert_predicate r, :valid?
  end

  def test_validates_presence_of_belongs_to_association__parent_is_new_record
    repair_validations(Interest) do
      # Note that Interest and Human have the :inverse_of option set
      Interest.validates_presence_of(:human)
      human = Human.new(name: "John")
      interest = human.interests.build(topic: "Airplanes")
      assert_predicate interest, :valid?, "Expected interest to be valid, but was not. Interest should have a human object associated"
    end
  end

  def test_validates_presence_of_belongs_to_association__existing_parent
    repair_validations(Interest) do
      Interest.validates_presence_of(:human)
      human = Human.create!(name: "John")
      interest = human.interests.build(topic: "Airplanes")
      assert_predicate interest, :valid?, "Expected interest to be valid, but was not. Interest should have a human object associated"
    end
  end

  def test_validates_associated_with_custom_context
    Reply.validates_associated :topic, on: :custom
    Topic.validates_presence_of :content, on: :custom
    r = Reply.create("title" => "A reply", "content" => "with content!")
    r.topic = Topic.create("title" => "uhohuhoh")
    assert_predicate r, :valid?
    assert_not r.valid?(:custom)
    assert_equal ["is invalid"], r.errors[:topic]
  end

  def test_validates_associated_with_create_context
    Reply.validates_associated :topic, on: :create
    Topic.validates_presence_of :content, on: :create
    t = Topic.create(title: "uhoh", content: "stuff")
    t.update!(content: nil)
    # NOTE: Does not pass along :create context from reply to Topic validation.
    r = t.replies.create(title: "A reply", content: "with content!")

    assert_predicate t, :valid?
    assert_predicate r, :valid?
  end
end
