# frozen_string_literal: true

require "cases/helper"

class AttributesDirtyTest < ActiveModel::TestCase
  class DirtyModel
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Dirty
    attribute :name, :string
    attribute :color, :string
    attribute :size, :integer

    def save
      changes_applied
    end
  end

  setup do
    @model = DirtyModel.new
  end

  test "setting attribute will result in change" do
    assert_not_predicate @model, :changed?
    assert_not_predicate @model, :name_changed?
    @model.name = "Ringo"
    assert_predicate @model, :changed?
    assert_predicate @model, :name_changed?
  end

  test "list of changed attribute keys" do
    assert_equal [], @model.changed
    @model.name = "Paul"
    assert_equal ["name"], @model.changed
  end

  test "changes to attribute values" do
    assert_not @model.changes["name"]
    @model.name = "John"
    assert_equal [nil, "John"], @model.changes["name"]
  end

  test "checking if an attribute has changed to a particular value" do
    @model.name = "Ringo"
    assert @model.name_changed?(from: nil, to: "Ringo")
    assert_not @model.name_changed?(from: "Pete", to: "Ringo")
    assert @model.name_changed?(to: "Ringo")
    assert_not @model.name_changed?(to: "Pete")
    assert @model.name_changed?(from: nil)
    assert_not @model.name_changed?(from: "Pete")
  end

  test "changes accessible through both strings and symbols" do
    @model.name = "David"
    assert_not_nil @model.changes[:name]
    assert_not_nil @model.changes["name"]
  end

  test "be consistent with symbols arguments after the changes are applied" do
    @model.name = "David"
    assert @model.attribute_changed?(:name)
    @model.save
    @model.name = "Rafael"
    assert @model.attribute_changed?(:name)
  end

  test "attribute mutation" do
    @model.name = "Yam"
    @model.save
    assert_not_predicate @model, :name_changed?
    @model.name.replace("Hadad")
    assert_predicate @model, :name_changed?
  end

  test "resetting attribute" do
    @model.name = "Bob"
    @model.restore_name!
    assert_nil @model.name
    assert_not_predicate @model, :name_changed?
  end

  test "setting color to same value should not result in change being recorded" do
    @model.color = "red"
    assert_predicate @model, :color_changed?
    @model.save
    assert_not_predicate @model, :color_changed?
    assert_not_predicate @model, :changed?
    @model.color = "red"
    assert_not_predicate @model, :color_changed?
    assert_not_predicate @model, :changed?
  end

  test "saving should reset model's changed status" do
    @model.name = "Alf"
    assert_predicate @model, :changed?
    @model.save
    assert_not_predicate @model, :changed?
    assert_not_predicate @model, :name_changed?
  end

  test "saving should preserve previous changes" do
    @model.name = "Jericho Cane"
    @model.save
    assert_equal [nil, "Jericho Cane"], @model.previous_changes["name"]
  end

  test "setting new attributes should not affect previous changes" do
    @model.name = "Jericho Cane"
    @model.save
    @model.name = "DudeFella ManGuy"
    assert_equal [nil, "Jericho Cane"], @model.name_previous_change
  end

  test "saving should preserve model's previous changed status" do
    @model.name = "Jericho Cane"
    @model.save
    assert_predicate @model, :name_previously_changed?
  end

  test "previous value is preserved when changed after save" do
    assert_equal({}, @model.changed_attributes)
    @model.name = "Paul"
    assert_equal({ "name" => nil }, @model.changed_attributes)

    @model.save

    @model.name = "John"
    assert_equal({ "name" => "Paul" }, @model.changed_attributes)
  end

  test "changing the same attribute multiple times retains the correct original value" do
    @model.name = "Otto"
    @model.save
    @model.name = "DudeFella ManGuy"
    @model.name = "Mr. Manfredgensonton"
    assert_equal ["Otto", "Mr. Manfredgensonton"], @model.name_change
    assert_equal "Otto", @model.name_was
  end

  test "using attribute_will_change! with a symbol" do
    @model.size = 1
    assert_predicate @model, :size_changed?
  end

  test "clear_changes_information should reset all changes" do
    @model.name = "Dmitry"
    @model.name_changed?
    @model.save
    @model.name = "Bob"

    assert_equal [nil, "Dmitry"], @model.previous_changes["name"]
    assert_equal "Dmitry", @model.changed_attributes["name"]

    @model.clear_changes_information

    assert_equal ActiveSupport::HashWithIndifferentAccess.new, @model.previous_changes
    assert_equal ActiveSupport::HashWithIndifferentAccess.new, @model.changed_attributes
  end

  test "restore_attributes should restore all previous data" do
    @model.name = "Dmitry"
    @model.color = "Red"
    @model.save
    @model.name = "Bob"
    @model.color = "White"

    @model.restore_attributes

    assert_not_predicate @model, :changed?
    assert_equal "Dmitry", @model.name
    assert_equal "Red", @model.color
  end

  test "restore_attributes can restore only some attributes" do
    @model.name = "Dmitry"
    @model.color = "Red"
    @model.save
    @model.name = "Bob"
    @model.color = "White"

    @model.restore_attributes(["name"])

    assert_predicate @model, :changed?
    assert_equal "Dmitry", @model.name
    assert_equal "White", @model.color
  end

  test "changing the attribute reports a change only when the cast value changes" do
    @model.size = "2.3"
    @model.save
    @model.size = "2.1"

    assert_equal false, @model.changed?

    @model.size = "5.1"

    assert_equal true, @model.changed?
    assert_equal true, @model.size_changed?
    assert_equal({ "size" => [2, 5] }, @model.changes)
  end
end
