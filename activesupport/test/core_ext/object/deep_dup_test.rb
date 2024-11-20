# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/deep_dup"

class DeepDupTest < ActiveSupport::TestCase
  def test_array_deep_dup
    array = [1, [2, 3]]
    dup = array.deep_dup
    dup[1][2] = 4
    assert_nil array[1][2]
    assert_equal 4, dup[1][2]
  end

  def test_hash_deep_dup
    hash = { a: { b: "b" } }
    dup = hash.deep_dup
    dup[:a][:c] = "c"
    assert_nil hash[:a][:c]
    assert_equal "c", dup[:a][:c]
  end

  def test_array_deep_dup_with_hash_inside
    array = [1, { a: 2, b: 3 } ]
    dup = array.deep_dup
    dup[1][:c] = 4
    assert_nil array[1][:c]
    assert_equal 4, dup[1][:c]
  end

  def test_hash_deep_dup_with_array_inside
    hash = { a: [1, 2] }
    dup = hash.deep_dup
    dup[:a][2] = "c"
    assert_nil hash[:a][2]
    assert_equal "c", dup[:a][2]
  end

  def test_deep_dup_initialize
    zero_hash = Hash.new 0
    hash = { a: zero_hash }
    dup = hash.deep_dup
    assert_equal 0, dup[:a][44]
  end

  def test_object_deep_dup
    object = Object.new
    dup = object.deep_dup
    dup.instance_variable_set(:@a, 1)
    assert_not object.instance_variable_defined?(:@a)
    assert dup.instance_variable_defined?(:@a)
  end

  def test_deep_dup_with_hash_class_key
    hash = { Integer => 1 }
    dup = hash.deep_dup
    assert_equal 1, dup.keys.length
  end

  def test_deep_dup_with_mutable_frozen_key
    key = { array: [] }.freeze
    hash = { key => :value }

    dup = hash.deep_dup
    dup.transform_keys { |k| k[:array] << :array_element }

    assert_not_equal hash.keys, dup.keys
  end

  def test_named_modules_arent_duped
    hash = { class: Object, module: Kernel }
    assert_equal hash, hash.deep_dup
  end

  def test_anonymous_modules_are_duped
    hash = { class: Class.new, module: Module.new }
    duped_hash = hash.deep_dup
    assert_not_equal hash[:class], duped_hash[:class]
    assert_not_equal hash[:module], duped_hash[:module]
  end
end
