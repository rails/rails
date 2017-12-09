# frozen_string_literal: true

require "cases/helper"

class DirtyTest < ActiveModel::TestCase
  class DirtyModel
    include ActiveModel::Dirty
    define_attribute_methods :name, :color, :size

    def initialize
      @name = nil
      @color = nil
      @size = nil
    end

    def name
      @name
    end

    def name=(val)
      name_will_change!
      @name = val
    end

    def color
      @color
    end

    def color=(val)
      color_will_change! unless val == @color
      @color = val
    end

    def size
      @size
    end

    def size=(val)
      attribute_will_change!(:size) unless val == @size
      @size = val
    end

    def save
      changes_applied
    end

    def reload
      clear_changes_information
    end
  end

  setup do
    @model = DirtyModel.new
  end

  test "setting attribute will result in change" do
    assert !@model.changed?
    assert !@model.name_changed?
    @model.name = "Ringo"
    assert @model.changed?
    assert @model.name_changed?
  end

  test "list of changed attribute keys" do
    assert_equal [], @model.changed
    @model.name = "Paul"
    assert_equal ["name"], @model.changed
  end

  test "changes to attribute values" do
    assert !@model.changes["name"]
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
    @model.instance_variable_set("@name", "Yam".dup)
    assert !@model.name_changed?
    @model.name.replace("Hadad")
    assert !@model.name_changed?
    @model.name_will_change!
    @model.name.replace("Baal")
    assert @model.name_changed?
  end

  test "resetting attribute" do
    @model.name = "Bob"
    @model.restore_name!
    assert_nil @model.name
    assert !@model.name_changed?
  end

  test "setting color to same value should not result in change being recorded" do
    @model.color = "red"
    assert @model.color_changed?
    @model.save
    assert !@model.color_changed?
    assert !@model.changed?
    @model.color = "red"
    assert !@model.color_changed?
    assert !@model.changed?
  end

  test "saving should reset model's changed status" do
    @model.name = "Alf"
    assert @model.changed?
    @model.save
    assert !@model.changed?
    assert !@model.name_changed?
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
    assert @model.name_previously_changed?
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
    assert_equal @model.name_was, "Otto"
  end

  test "using attribute_will_change! with a symbol" do
    @model.size = 1
    assert @model.size_changed?
  end

  test "reload should reset all changes" do
    @model.name = "Dmitry"
    @model.name_changed?
    @model.save
    @model.name = "Bob"

    assert_equal [nil, "Dmitry"], @model.previous_changes["name"]
    assert_equal "Dmitry", @model.changed_attributes["name"]

    @model.reload

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

    assert_not @model.changed?
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

    assert @model.changed?
    assert_equal "Dmitry", @model.name
    assert_equal "White", @model.color
  end

  test "model can be dup-ed without Attributes" do
    assert @model.dup
  end
end
