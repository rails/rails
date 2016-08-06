require "abstract_unit"
require "active_support/core_ext/object"

class DeepDupTest < ActiveSupport::TestCase

  def test_array_deep_dup
    array = [1, [2, 3]]
    dup = array.deep_dup
    dup[1][2] = 4
    assert_equal nil, array[1][2]
    assert_equal 4, dup[1][2]
  end

  def test_hash_deep_dup
    hash = { a: { b: "b" } }
    dup = hash.deep_dup
    dup[:a][:c] = "c"
    assert_equal nil, hash[:a][:c]
    assert_equal "c", dup[:a][:c]
  end

  def test_array_deep_dup_with_hash_inside
    array = [1, { a: 2, b: 3 } ]
    dup = array.deep_dup
    dup[1][:c] = 4
    assert_equal nil, array[1][:c]
    assert_equal 4, dup[1][:c]
  end

  def test_hash_deep_dup_with_array_inside
    hash = { a: [1, 2] }
    dup = hash.deep_dup
    dup[:a][2] = "c"
    assert_equal nil, hash[:a][2]
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
    assert !object.instance_variable_defined?(:@a)
    assert dup.instance_variable_defined?(:@a)
  end

  def test_deep_dup_with_hash_class_key
    hash = { Integer => 1 }
    dup = hash.deep_dup
    assert_equal 1, dup.keys.length
  end

end
