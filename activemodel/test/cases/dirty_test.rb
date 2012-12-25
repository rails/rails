require "cases/helper"

class DirtyTest < ActiveModel::TestCase
  class DirtyModel
    include ActiveModel::Dirty
    define_attribute_methods :name, :color

    def initialize
      @name = nil
      @color = nil
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

    def save
      @previously_changed = changes
      @changed_attributes.clear
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

  test "list of changed attributes" do
    assert_equal [], @model.changed
    @model.name = "Paul"
    assert_equal ['name'], @model.changed
  end

  test "changes to attribute values" do
    assert !@model.changes['name']
    @model.name = "John"
    assert_equal [nil, "John"], @model.changes['name']
  end

  test "changes accessible through both strings and symbols" do
    @model.name = "David"
    assert_not_nil @model.changes[:name]
    assert_not_nil @model.changes['name']
  end

  test "attribute mutation" do
    @model.instance_variable_set("@name", "Yam")
    assert !@model.name_changed?
    @model.name.replace("Hadad")
    assert !@model.name_changed?
    @model.name_will_change!
    @model.name.replace("Baal")
    assert @model.name_changed?
  end

  test "resetting attribute" do
    @model.name = "Bob"
    @model.reset_name!
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
    assert_equal [nil, "Jericho Cane"], @model.previous_changes['name']
  end

  test "changing the same attribute multiple times retains the correct original value" do
    @model.name = "Otto"
    @model.save
    @model.name = "DudeFella ManGuy"
    @model.name = "Mr. Manfredgensonton"
    assert_equal ["Otto", "Mr. Manfredgensonton"], @model.name_change
    assert_equal @model.name_was, "Otto"
  end
end
