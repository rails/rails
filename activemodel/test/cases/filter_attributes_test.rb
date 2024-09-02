# frozen_string_literal: true

require "cases/helper"
require "models/topic"

class InspectTest < ActiveModel::TestCase
  test "attribute_for_inspect with a string" do
    t = Topic.new
    t.title = "The First Topic Now Has A Title With\nNewlines And More Than 50 Characters"

    assert_equal '"The First Topic Now Has A Title With\nNewlines And ..."', t.attribute_for_inspect(:title)
  end

  test "attribute_for_inspect with a date" do
    t = Topic.new created_at: 1.hour.ago

    assert_equal %("#{t.created_at.to_fs(:inspect)}"), t.attribute_for_inspect(:created_at)
  end

  test "attribute_for_inspect with an array" do
    t = Topic.new content: ["some_value"]

    assert_match %r(\["some_value"\]), t.attribute_for_inspect(:content)
  end

  test "attribute_for_inspect with a long array" do
    t = Topic.new content: (1..11).to_a

    assert_equal "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]", t.attribute_for_inspect(:content)
  end
end
