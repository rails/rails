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

  repair_validations(Topic)

  def test_validates_size_of_association
    repair_validations(Owner) do
      assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors[:pets].any?
      pet = o.pets.build('name' => 'apet')
      assert o.valid?
    end
  end

  def test_validates_size_of_association_using_within
    repair_validations(Owner) do
      assert_nothing_raised { Owner.validates_size_of :pets, :within => 1..2 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors[:pets].any?

      pet = o.pets.build('name' => 'apet')
      assert o.valid?

      2.times { o.pets.build('name' => 'apet') }
      assert !o.save
      assert o.errors[:pets].any?
    end
  end

  def test_validates_associated_many
    Topic.validates_associated( :replies )
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
    repair_validations(Reply) do
      Reply.validates_associated( :topic )
      Topic.validates_presence_of( :content )
      r = Reply.new("title" => "A reply", "content" => "with content!")
      r.topic = Topic.create("title" => "uhohuhoh")
      assert !r.valid?
      assert r.errors[:topic].any?
      r.topic.content = "non-empty"
      assert r.valid?
    end
  end

  def test_validates_associated_with_custom_message_using_quotes
    repair_validations(Reply) do
      Reply.validates_associated :topic, :message=> "This string contains 'single' and \"double\" quotes"
      Topic.validates_presence_of :content
      r = Reply.create("title" => "A reply", "content" => "with content!")
      r.topic = Topic.create("title" => "uhohuhoh")
      assert !r.valid?
      assert_equal ["This string contains 'single' and \"double\" quotes"], r.errors[:topic]
    end
  end

  def test_validates_associated_missing
    repair_validations(Reply) do
      Reply.validates_presence_of(:topic)
      r = Reply.create("title" => "A reply", "content" => "with content!")
      assert !r.valid?
      assert r.errors[:topic].any?

      r.topic = Topic.find :first
      assert r.valid?
    end
  end

  def test_validates_size_of_association_utf8
    repair_validations(Owner) do
      with_kcode('UTF8') do
        assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
        o = Owner.new('name' => 'あいうえおかきくけこ')
        assert !o.save
        assert o.errors[:pets].any?
        o.pets.build('name' => 'あいうえおかきくけこ')
        assert o.valid?
      end
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

end
