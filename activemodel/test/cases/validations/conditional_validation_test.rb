# frozen_string_literal: true

require 'cases/helper'

require 'models/topic'

class ConditionalValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  def test_if_validation_using_method_true
    # When the method returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', if: :condition_is_true)
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ['hoo 5'], t.errors['title']
  end

  def test_if_validation_using_array_of_true_methods
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', if: [:condition_is_true, :condition_is_true])
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ['hoo 5'], t.errors['title']
  end

  def test_unless_validation_using_array_of_false_methods
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', unless: [:condition_is_false, :condition_is_false])
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ['hoo 5'], t.errors['title']
  end

  def test_unless_validation_using_method_true
    # When the method returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', unless: :condition_is_true)
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :valid?
    assert_empty t.errors[:title]
  end

  def test_if_validation_using_array_of_true_and_false_methods
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', if: [:condition_is_true, :condition_is_false])
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :valid?
    assert_empty t.errors[:title]
  end

  def test_unless_validation_using_array_of_true_and_false_methods
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', unless: [:condition_is_true, :condition_is_false])
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :valid?
    assert_empty t.errors[:title]
  end

  def test_if_validation_using_method_false
    # When the method returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', if: :condition_is_false)
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :valid?
    assert_empty t.errors[:title]
  end

  def test_unless_validation_using_method_false
    # When the method returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', unless: :condition_is_false)
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ['hoo 5'], t.errors['title']
  end

  def test_if_validation_using_block_true
    # When the block returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}',
      if: Proc.new { |r| r.content.size > 4 })
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ['hoo 5'], t.errors['title']
  end

  def test_unless_validation_using_block_true
    # When the block returns true
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}',
      unless: Proc.new { |r| r.content.size > 4 })
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :valid?
    assert_empty t.errors[:title]
  end

  def test_if_validation_using_block_false
    # When the block returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}',
      if: Proc.new { |r| r.title != 'uhohuhoh' })
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :valid?
    assert_empty t.errors[:title]
  end

  def test_unless_validation_using_block_false
    # When the block returns false
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}',
      unless: Proc.new { |r| r.title != 'uhohuhoh' })
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ['hoo 5'], t.errors['title']
  end

  def test_validation_using_combining_if_true_and_unless_true_conditions
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', if: :condition_is_true, unless: :condition_is_true)
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :valid?
    assert_empty t.errors[:title]
  end

  def test_validation_using_combining_if_true_and_unless_false_conditions
    Topic.validates_length_of(:title, maximum: 5, too_long: 'hoo %{count}', if: :condition_is_true, unless: :condition_is_false)
    t = Topic.new('title' => 'uhohuhoh', 'content' => 'whatever')
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ['hoo 5'], t.errors['title']
  end
end
