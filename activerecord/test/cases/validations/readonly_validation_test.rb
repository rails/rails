# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"

class ReadonlyValidationTest < ActiveRecord::TestCase
  fixtures :topics

  repair_validations(Topic)

  test "readonly attributes can be set on creation" do
    Topic.validates :title, readonly: true
    t = Topic.new(title: "Ruby")
    assert_predicate t, :valid?
  end

  test "readonly attributes can be updated before persisting" do
    Topic.validates :title, readonly: true
    t = Topic.new(title: "Ruby")
    t.update(title: "Ruby is great!")
    assert_predicate t, :valid?
  end

  test "validates persisted attribute can not be changed" do
    Topic.validates :title, readonly: true
    t = Topic.create!(title: "Ruby")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      t.update!(title: "Ruby is great!")
    end

    assert_equal("Validation failed: Title is readonly", error.message)
  end

  test "validates persisted association can not be changed" do
    Reply.validates :topic, readonly: true

    r = Reply.create!(title: "Yes it is!")

    Topic.create!(title: "Ruby is great!", replies: [r])

    error = assert_raises(ActiveRecord::RecordInvalid) do
      r.update!(topic: Topic.create!(title: "Rails is great!"))
    end
    assert_equal("Validation failed: Topic is readonly", error.message)
  end
end
