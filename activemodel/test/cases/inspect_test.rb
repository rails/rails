# frozen_string_literal: true

require "cases/helper"
require "models/contact"
require "models/user"
require "pp"

class FilterAttributesTest < ActiveModel::TestCase
  setup do
    @previous_filter_attributes = ActiveModel::Inspect.filter_attributes
    ActiveModel::Inspect.filter_attributes = [:name]
    Contact.filter_attributes = nil
  end

  teardown do
    ActiveModel::Inspect.filter_attributes = @previous_filter_attributes
    Contact.filter_attributes = nil
  end

  test "filter_attributes" do
    contact = Contact.new(name: "37signals")
    assert_includes contact.inspect, "name: [FILTERED]"
    assert_equal 1, contact.inspect.scan("[FILTERED]").length
  end

  test "filter_attributes affects attribute_for_inspect" do
    contact = Contact.new(name: "37signals")
    assert_equal "[FILTERED]", contact.attribute_for_inspect(:name)
  end

  test "string filter_attributes perform partial match" do
    ActiveModel::Inspect.filter_attributes = ["n"]
    contact = Contact.new(name: "37signals")
    assert_includes contact.inspect, "name: [FILTERED]"
    assert_equal 1, contact.inspect.scan("[FILTERED]").length
  end

  test "regex filter_attributes are accepted" do
    ActiveModel::Inspect.filter_attributes = [/\An\z/]
    contact = Contact.new(name: "37signals")
    assert_includes contact.inspect, 'name: "37signals"'
    assert_equal 0, contact.inspect.scan("[FILTERED]").length

    Contact.instance_variable_set(:@filter_attributes, nil)
    Contact.instance_variable_set(:@inspection_filter, nil)
    ActiveModel::Inspect.filter_attributes = [/\An/]
    contact = Contact.new(name: "37signals")
    assert_includes contact.inspect, "name: [FILTERED]"
    assert_equal 1, contact.inspect.scan("[FILTERED]").length
  end

  test "proc filter_attributes are accepted" do
    ActiveModel::Inspect.filter_attributes = [ lambda { |key, value| value.reverse! if key == "name" } ]
    contact = Contact.new(name: "37signals")
    assert_includes contact.inspect, 'name: "slangis73"'
  end

  test "filter_attributes could be overwritten by models" do
    contact = Contact.new(name: "37signals")

    assert_includes contact.inspect, "name: [FILTERED]"
    assert_equal 1, contact.inspect.scan("[FILTERED]").length

    Contact.filter_attributes = []

    ## Above changes should not impact other models
    user = User.new
    user.name = "37signals"
    assert_includes user.inspect, "name: [FILTERED]"
    assert_equal 1, user.inspect.scan("[FILTERED]").length

    contact = Contact.new(name: "37signals")
    assert_not_includes contact.inspect, "name: [FILTERED]"
    assert_equal 0, contact.inspect.scan("[FILTERED]").length
  end

  test "filter_attributes should not filter nil value" do
    contact = Contact.new name: nil

    assert_includes contact.inspect, "name: nil"
    assert_not_includes contact.inspect, "name: [FILTERED]"
    assert_equal 0, contact.inspect.scan("[FILTERED]").length
  end

  test "filter_attributes should handle [FILTERED] value properly" do
    Contact.filter_attributes = ["age"]
    contact = Contact.new(age: 20, name: "[FILTERED]")

    assert_includes contact.inspect, "age: [FILTERED]"
    assert_includes contact.inspect, "name: \"[FILTERED]\""
  end

  test "filter_attributes on pretty_print" do
    contact = Contact.new(name: "37signals")
    actual = "".dup
    PP.pp(contact, StringIO.new(actual))

    assert_includes actual, "name: [FILTERED]"
    assert_equal 1, actual.scan("[FILTERED]").length
  end

  test "filter_attributes on pretty_print should not filter nil value" do
    contact = Contact.new(name: nil)
    actual = "".dup
    PP.pp(contact, StringIO.new(actual))

    assert_includes actual, "name: nil"
    assert_not_includes actual, "name: [FILTERED]"
    assert_equal 0, actual.scan("[FILTERED]").length
  end

  test "filter_attributes on pretty_print should handle [FILTERED] value properly" do
    Contact.filter_attributes = ["age"]

    contact = Contact.new(age: 20, name: "[FILTERED]")
    actual = "".dup
    PP.pp(contact, StringIO.new(actual))

    assert_includes actual, "age: [FILTERED]"
    assert_includes actual, "name: \"[FILTERED]\""
  end
end
