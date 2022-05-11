# frozen_string_literal: true

require "cases/helper"
require "models/topic"

class CompositeValidatorTest < ActiveModel::TestCase
  class Topic < ::Topic
    class BetterThanBadValidator < ActiveModel::CompositeValidator
      def compose
        bad = options[:bad] || "bad"
        validates(*attributes, length: { minimum: bad.length + 1, message: "is not longer" })
        validates_comparison_of(*attributes, greater_than: bad, message: "is not greater")
      end
    end
  end

  teardown do
    Topic.clear_validators!
  end

  test "composes validators" do
    Topic.validates :title, better_than_bad: true

    assert Topic.new(title: "good").valid?
    assert_errors ["Title is not longer"], Topic.new(title: "boo")
    assert_errors ["Title is not greater"], Topic.new(title: "baaad")
    assert_errors ["Title is not longer", "Title is not greater"], Topic.new(title: "bad")
  end

  test "supports multiple attributes" do
    Topic.validates :title, :content, better_than_bad: true

    assert Topic.new(title: "good", content: "good").valid?
    assert_errors ["Title is not greater", "Content is not longer"], Topic.new(title: "baaad", content: "lol")
  end

  test "supports custom options" do
    Topic.validates :title, better_than_bad: { bad: "good" }

    assert Topic.new(title: "great").valid?
    assert_errors ["Title is not longer"], Topic.new(title: "gr8")
    assert_errors ["Title is not greater"], Topic.new(title: "get good")
    assert_errors ["Title is not longer", "Title is not greater"], Topic.new(title: "good")
  end

  test "forwards standard options" do
    if_count = 0
    unless_count = 0
    Topic.validates :title, better_than_bad: true,
      on: :testing_standard_options,
      if: proc { if_count += 1; true },
      unless: proc { unless_count += 1; false },
      strict: true

    assert Topic.new(title: "bad").valid?
    assert_equal 0, if_count
    assert_equal 0, unless_count

    assert Topic.new(title: "good").valid?(:testing_standard_options)
    assert_equal 2, if_count
    assert_equal 2, unless_count

    assert_raises(ActiveModel::StrictValidationFailed) do
      Topic.new(title: "bad").valid?(:testing_standard_options)
    end
  end

  private
    def assert_errors(errors, model, context: nil)
      model.valid?(context)
      assert_equal errors.sort, model.errors.full_messages.sort
    end
end
