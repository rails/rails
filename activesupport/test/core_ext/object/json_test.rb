# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/json"

class ObjectAsJsonTests < ActiveSupport::TestCase
  class Sample
    def initialize(attributes)
      attributes.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
    end
  end

  class SampleWithHash
    def initialize(attributes)
      @attributes = attributes
    end

    def to_hash
      @attributes
    end
  end

  def test_simple_poro
    object = Sample.new(name: "foo", value: "bar")
    assert_equal({ "name" => "foo", "value" => "bar" }, object.as_json)
  end

  def test_with_to_hash
    hash = { foo: "bar" }
    object = SampleWithHash.new(hash)
    assert_equal(hash.as_json, object.as_json)
  end

  def test_nested_objects
    children = []
    object = Sample.new(name: "parent", children: children)
    child_1 = Sample.new(name: "child_1")
    child_2 = Sample.new(name: "child_2")
    children.concat([child_1, child_2])
    assert_equal({ "name" => "parent", "children" => [{ "name" => "child_1" }, { "name" => "child_2" }] }, object.as_json)
  end

  def test_nested_objects_with_backreferences
    children = []
    object = Sample.new(name: "parent", children: children)
    child_1 = Sample.new(name: "child_1", parent: object)
    child_2 = Sample.new(name: "child_2", parent: child_1)
    child_3 = Sample.new(name: "child_3")
    child_4 = Sample.new(name: "child_4", parent: { owner: child_3 })
    children.concat([child_1, child_2, child_4])
    expected_hash = {
      "name" => "parent",
      "children" => [
        { "name" => "child_1" },
        { "name" => "child_2", "parent" => { "name" => "child_1" } },
        { "name" => "child_4", "parent" => { "owner" => { "name" => "child_3" } } },
      ]
    }
    assert_equal(expected_hash, object.as_json)
  end
end
