# frozen_string_literal: true

require "cases/helper"

class IndexedRowTest < ActiveModel::TestCase
  setup do
    @hash = { "first_name" => "George", "last_name" => "Abitbol", "age" => 42 }.freeze
    @row = ActiveModel::IndexedRow[@hash]
  end

  test "#[]" do
    assert_equal "George", @row["first_name"]
    assert_equal "Abitbol", @row["last_name"]
    assert_equal 42, @row["age"]
    assert_nil @row["missing"]
  end

  test "#size" do
    assert_equal @hash.size, @row.size
  end

  test "#keys" do
    assert_equal @hash.keys, @row.keys
  end

  test "#values" do
    assert_equal @hash.values, @row.values
  end

  test "#==" do
    assert_equal @hash, @row
  end

  test "#key?" do
    assert_equal true, @row.key?("first_name")
    assert_equal true, @row.key?("last_name")
    assert_equal true, @row.key?("age")
    assert_equal false, @row.key?("missing")
  end

  test "#fetch" do
    assert_equal 42, @row.fetch("age")
    assert_raises(KeyError) do
      @row.fetch("missing")
    end
    assert_equal(1, @row.fetch("missing") { 1 })
  end

  test "#to_h" do
    assert_equal @hash, @row.to_h
  end
end

class EmptyMutableIndexedRowTest < ActiveModel::TestCase
  setup do
    @hash = { "first_name" => "George", "last_name" => "Abitbol", "age" => 42 }.freeze
    @reference = ActiveModel::IndexedRow[@hash]
    @row = @reference.new_empty_mutable_row
  end

  test "#[]" do
    assert_nil @row["first_name"]
    assert_nil @row["last_name"]
    assert_nil @row["age"]
    assert_nil @row["missing"]
  end

  test "#[]=" do
    assert_nil @row["age"]
    @row["age"] = 42
    assert_equal 42, @row["age"]

    assert_raises KeyError do
      @row["missing"] = true
    end
  end

  test "#size" do
    assert_equal 0, @row.size
    @row["age"] = 42
    assert_equal 1, @row.size
    @row["first_name"] = "George"
    assert_equal 2, @row.size
  end

  test "#keys" do
    assert_equal [], @row.keys
    @row["age"] = 42
    assert_equal ["age"], @row.keys
    @row["first_name"] = "George"
    assert_equal ["first_name", "age"], @row.keys
  end

  test "#values" do
    assert_equal [], @row.values
    @row["age"] = 42
    assert_equal [42], @row.values
    @row["first_name"] = "George"
    assert_equal ["George", 42], @row.values
  end

  test "#fetch" do
    assert_raises(KeyError) { @row.fetch("age") }
    assert_equal(4, @row.fetch("age") { 4 })
    @row["age"] = 42
    assert_equal 42, @row.fetch("age")
  end
end
