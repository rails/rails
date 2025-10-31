# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/hash/indifferent_access"

class AccessTest < ActiveModel::TestCase
  class Point
    include ActiveModel::Access

    def initialize(*vector)
      @vector = vector
    end

    def x
      @vector[0]
    end

    def y
      @vector[1]
    end

    def z
      @vector[2]
    end
  end

  setup do
    @point = Point.new(123, 456, 789)
  end

  test "slice" do
    expected = { z: @point.z, x: @point.x }.with_indifferent_access
    actual = @point.slice(:z, :x)

    assert_equal expected.keys, actual.keys

    expected.each do |key, value|
      assert_equal value, actual[key.to_s]
      assert_equal value, actual[key.to_sym]
    end
  end

  test "slice with array" do
    expected = { z: @point.z, x: @point.x }.with_indifferent_access

    assert_equal expected, @point.slice([:z, :x])
  end

  test "slice with block" do
    expected = { z: @point.z }.with_indifferent_access
    actual = @point.slice { |method| [:z].include?(method) }

    assert_equal expected.keys, actual.keys
  end

  test "slice with block filtering multiple methods" do
    expected = { x: @point.x, z: @point.z }.with_indifferent_access
    actual = @point.slice { |method| [:x, :z].include?(method) }

    assert_equal expected.keys.sort, actual.keys.sort

    expected.each do |key, value|
      assert_equal value, actual[key.to_s]
      assert_equal value, actual[key.to_sym]
    end
  end

  test "slice with block returning empty result" do
    expected = {}.with_indifferent_access
    actual = @point.slice { |method| false }

    assert_equal expected, actual
    assert_equal 0, actual.keys.length
  end

  test "slice with missing method" do
    assert_raise(NoMethodError) { @point.slice(:a) }
  end

  test "values_at" do
    assert_equal [@point.x, @point.z], @point.values_at(:x, :z)
    assert_equal [@point.z, @point.x], @point.values_at(:z, :x)
  end

  test "values_at with array" do
    assert_equal [@point.x, @point.z], @point.values_at([:x, :z])
    assert_equal [@point.z, @point.x], @point.values_at([:z, :x])
  end
end
