# encoding: utf-8
require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/owner'
require 'models/pet'
require 'models/man'
require 'models/interest'

class AssociationValidationTest < ActiveRecord::TestCase
  fixtures :topics, :owners

  repair_validations(Topic, Reply)

  def test_validates_size_of_association
    repair_validations Owner do
      assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors[:pets].any?
      o.pets.build('name' => 'apet')
      assert o.valid?
    end
  end

  def test_validates_size_of_association_using_within
    repair_validations Owner do
      assert_nothing_raised { Owner.validates_size_of :pets, :within => 1..2 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors[:pets].any?

      o.pets.build('name' => 'apet')
      assert o.valid?

      2.times { o.pets.build('name' => 'apet') }
      assert !o.save
      assert o.errors[:pets].any?
    end
  end

  def test_validates_associated_many
    Topic.validates_associated(:replies)
    Reply.validates_presence_of(:content)
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    t.replies << [r = Reply.new("title" => "A reply"), r2 = Reply.new("title" => "Another reply", "content" => "non-empty"), r3 = Reply.new("title" => "Yet another reply"), r4 = Reply.new("title" => "The last reply", "content" => "non-empty")]
    assert !t.valid?
    assert t.errors[:replies].any?
    assert_equal 1, r.errors.count  # make sure all associated objects have been validated
    assert_equal 0, r2.errors.count
    assert_equal 1, r3.errors.count
    assert_equal 0, r4.errors.count
    r.content = r3.content = "non-empty"
    assert t.valid?
  end

  def test_validates_associated_one
    Reply.validates :topic, :associated => true
    Topic.validates_presence_of( :content )
    r = Reply.new("title" => "A reply", "content" => "with content!")
    r.topic = Topic.create("title" => "uhohuhoh")
    assert !r.valid?
    assert r.errors[:topic].any?
    r.topic.content = "non-empty"
    assert r.valid?
  end

  def test_validates_associated_marked_for_destruction
    Topic.validates_associated(:replies)
    Reply.validates_presence_of(:content)
    t = Topic.new
    t.replies << Reply.new
    assert t.invalid?
    t.replies.first.mark_for_destruction
    assert t.valid?
  end

  def test_validates_associated_with_custom_message_using_quotes
    Reply.validates_associated :topic, :message=> "This string contains 'single' and \"double\" quotes"
    Topic.validates_presence_of :content
    r = Reply.create("title" => "A reply", "content" => "with content!")
    r.topic = Topic.create("title" => "uhohuhoh")
    assert !r.valid?
    assert_equal ["This string contains 'single' and \"double\" quotes"], r.errors[:topic]
  end

  def test_validates_associated_missing
    Reply.validates_presence_of(:topic)
    r = Reply.create("title" => "A reply", "content" => "with content!")
    assert !r.valid?
    assert r.errors[:topic].any?

    r.topic = Topic.first
    assert r.valid?
  end

  def test_validates_size_of_association_utf8
    repair_validations Owner do
      assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
      o = Owner.new('name' => 'あいうえおかきくけこ')
      assert !o.save
      assert o.errors[:pets].any?
      o.pets.build('name' => 'あいうえおかきくけこ')
      assert o.valid?
    end
  end

  def test_validates_presence_of_belongs_to_association__parent_is_new_record
    repair_validations(Interest) do
      # Note that Interest and Man have the :inverse_of option set
      Interest.validates_presence_of(:man)
      man = Man.new(:name => 'John')
      interest = man.interests.build(:topic => 'Airplanes')
      assert interest.valid?, "Expected interest to be valid, but was not. Interest should have a man object associated"
    end
  end

  def test_validates_presence_of_belongs_to_association__existing_parent
    repair_validations(Interest) do
      Interest.validates_presence_of(:man)
      man = Man.create!(:name => 'John')
      interest = man.interests.build(:topic => 'Airplanes')
      assert interest.valid?, "Expected interest to be valid, but was not. Interest should have a man object associated"
    end
  end

  def test_validates_associated_models_in_the_same_context
    Topic.validates_presence_of :title, :on => :custom_context
    Topic.validates_associated :replies
    Reply.validates_presence_of :title, :on => :custom_context

    t = Topic.new('title' => '')
    r = t.replies.new('title' => '')

    assert t.valid?
    assert !t.valid?(:custom_context)

    t.title = "Longer"
    assert !t.valid?(:custom_context), "Should NOT be valid if the associated object is not valid in the same context."

    r.title = "Longer"
    assert t.valid?(:custom_context), "Should be valid if the associated object is not valid in the same context."
  end

  def test_validates_associated_many_uniqueness
    Topic.validates_associated(:replies)
    Reply.validates_uniqueness_of(:title)

    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    t.replies << [r = Reply.new("title" => "A reply"), r2 = Reply.new("title" => "Another reply"), r3 = Reply.new("title" => "Another reply")]

    assert !t.valid?
    assert t.errors[:replies].any?
    assert_equal 0, r.errors.count  # make sure all associated objects have been validated
    assert_equal 0, r2.errors.count
    assert_equal 1, r3.errors.count

    r3.title = "New reply"
    assert t.valid?
  end

  def test_ignore_on_empty_validates_associated_nested_attributes_uniqueness
    Topic.validates_associated(:replies)
    Topic.accepts_nested_attributes_for(:replies)

    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    t.replies_attributes = []

    assert t.valid?
    t.save!
    assert_equal 0, t.replies.count
  end

  def test_ignore_validates_associated_nested_attributes_uniqueness
    Topic.validates_associated(:replies)
    Topic.accepts_nested_attributes_for(:replies)

    # There is no uniquness on Reply, therefore it should allow duplicates.
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    t.replies_attributes = [{ "title" => "A reply" }, { "title" => "Another reply" }, { "title" => "Another reply" }]

    assert t.valid?
    t.save!
    assert_equal 3, t.replies.count
  end

  def test_validates_associated_nested_attributes_uniqueness
    Topic.validates_associated(:replies)
    Topic.accepts_nested_attributes_for(:replies)
    Reply.validates_uniqueness_of(:title)

    t = Topic.create("title" => "My Title", "content" => "This is so boss.")
    t.replies_attributes = [{ "title" => "A reply" }, { "title" => "Another reply" }, { "title" => "Another reply" }]
    assert !t.valid?

    new_t = Topic.create("title" => "My better title", "content" => "This is so boss.")
    new_t.replies_attributes = [{ "title" => "A reply" }, { "title" => "It really isn't that boss." }, { "title" => "Actually, yes this is pretty boss." }]

    assert new_t.valid?
    new_t.save!
    assert_equal 3, new_t.replies.size
  end

  def test_validates_associated_nested_attributes_uniqueness_with_scoping
    Topic.validates_associated(:replies)
    Topic.accepts_nested_attributes_for(:replies)
    Reply.validates_uniqueness_of(:title, :scope => :content)

    t = Topic.create("title" => "Brogramming", "content" => "Programming, for bros.")
    t.replies_attributes = [{"title" => "Reply", "content" => "Some content"}, {"title" => "Reply", "content" => "Some content"}]
    assert !t.valid?

    new_t = Topic.create("title" => "Programming", "content" => "For the masses")
    new_t.replies_attributes = [{"title" => "aa", "content" => "aa"}, {"title" => "a", :content => "aaa"}, {"title" => "Apple", :content => "Boy"}]

    assert new_t.valid?
    new_t.save!
    assert_equal 3, new_t.replies.size
  end
end
