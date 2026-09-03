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
