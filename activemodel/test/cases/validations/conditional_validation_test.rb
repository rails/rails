# frozen_string_literal: true

require "cases/helper"

require "models/topic"

class ConditionalValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  def test_if_validation_using_method_true
    # When the method returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}", if: :condition_is_true)
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.invalid?
    assert t.errors[:title].any?
    assert_equal ["hoo 5"], t.errors["title"]
  end

  def test_unless_validation_using_method_true
    # When the method returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}", unless: :condition_is_true)
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert_empty t.errors[:title]
  end

  def test_if_validation_using_method_false
    # When the method returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}", if: :condition_is_true_but_its_not)
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert_empty t.errors[:title]
  end

  def test_unless_validation_using_method_false
    # When the method returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}", unless: :condition_is_true_but_its_not)
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.invalid?
    assert t.errors[:title].any?
    assert_equal ["hoo 5"], t.errors["title"]
  end

  def test_if_validation_using_block_true
    # When the block returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}",
      if: Proc.new { |r| r.content.size > 4 })
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.invalid?
    assert t.errors[:title].any?
    assert_equal ["hoo 5"], t.errors["title"]
  end

  def test_unless_validation_using_block_true
    # When the block returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}",
      unless: Proc.new { |r| r.content.size > 4 })
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert_empty t.errors[:title]
  end

  def test_if_validation_using_block_false
    # When the block returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}",
      if: Proc.new { |r| r.title != "uhohuhoh" })
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert_empty t.errors[:title]
  end

  def test_unless_validation_using_block_false
    # When the block returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}",
      unless: Proc.new { |r| r.title != "uhohuhoh" })
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert t.invalid?
    assert t.errors[:title].any?
    assert_equal ["hoo 5"], t.errors["title"]
  end
end
