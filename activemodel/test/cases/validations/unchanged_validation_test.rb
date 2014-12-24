# encoding: utf-8
require 'cases/helper'
require 'models/dirty_model'

class UnchangedValidationTest < ActiveModel::TestCase

  teardown do
    DirtyModel.clear_validators!
  end

  def test_validate_unchanged
    d = DirtyModel.new
    d.name = 'dave'
    d.color = 'green'
    d.save

    DirtyModel.validates_unchanged(:name, :color)

    d.name = 'bob'
    d.color = 'green'
    assert d.invalid?
    assert_equal ['must not change'], d.errors[:name]
    assert_equal [], d.errors[:color]

    d = DirtyModel.new
    assert d.valid?

    d = DirtyModel.new
    d.name = 'dave'
    d.color = 'red'
    d.save
  end

  def test_validates_unchanged_with_array_arguments
    d = DirtyModel.new
    d.name = 'dave'
    d.color = 'green'
    d.save
    
    DirtyModel.validates_unchanged %w(name color)

    d.name = 'bob'
    d.color = 'red'
    assert d.invalid?
    assert_equal ['must not change'], d.errors[:name]
    assert_equal ['must not change'], d.errors[:color]
  end

  def test_validates_unchanged_with_custom_error_using_quotes
    DirtyModel.validates_unchanged :name, message: "This string contains 'single' and \"double\" quotes"
    d = DirtyModel.new
    d.save
    d.name = 'bob'
    assert d.invalid?
    assert_equal ["This string contains 'single' and \"double\" quotes"], d.errors[:name]
  end

  def test_validates_unchanged_with_allow_nil_option
    d = DirtyModel.new
    d.color = 'green'
    d.save

    DirtyModel.validates_unchanged(:color, allow_nil: true)

    d.color = 'green'
    assert d.valid?, d.errors.full_messages

    d.color = 'red'
    assert d.invalid?
    assert_equal ['must not change'], d.errors[:color]

    d.color = ""
    assert d.invalid?
    assert_equal ['must not change'], d.errors[:color]

    d.color = nil
    assert d.valid?, d.errors.full_messages
  end

  def test_unchanged_with_allow_blank_option
    d = DirtyModel.new
    d.color = 'green'
    d.save

    DirtyModel.validates_unchanged(:color, allow_blank: true)

    d.color = 'green'
    assert d.valid?, d.errors.full_messages

    d.color = ""
    assert d.valid?, d.errors.full_messages

    d.color = "  "
    assert d.valid?, d.errors.full_messages

    d.color = nil
    assert d.valid?, d.errors.full_messages
  end
end
