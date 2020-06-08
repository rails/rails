# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class ResultTest < ActiveRecord::TestCase
    def result
      Result.new(["col_1", "col_2"], [
        ["row 1 col 1", "row 1 col 2"],
        ["row 2 col 1", "row 2 col 2"],
        ["row 3 col 1", "row 3 col 2"],
      ])
    end

    test "includes_column?" do
      assert result.includes_column?("col_1")
      assert_not result.includes_column?("foo")
    end

    test "length" do
      assert_equal 3, result.length
    end

    test "to_a returns row_hashes" do
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.to_a
    end

    test "to_hash (deprecated) returns row_hashes" do
      assert_deprecated do
        assert_equal [
          { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
          { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
          { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
        ], result.to_hash
      end
    end

    test "first returns first row as a hash" do
      assert_equal(
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" }, result.first)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
      ], result.first(1)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
      ], result.first(2)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.first(3)
    end

    test "last returns last row as a hash" do
      assert_equal(
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" }, result.last)
      assert_equal [
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.last(1)
      assert_equal [
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.last(2)
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.last(3)
    end

    test "each with block returns row hashes" do
      result.each do |row|
        assert_equal ["col_1", "col_2"], row.keys
      end
    end

    test "each without block returns an enumerator" do
      result.each.with_index do |row, index|
        assert_equal ["col_1", "col_2"], row.keys
        assert_kind_of Integer, index
      end
    end

    test "each without block returns a sized enumerator" do
      assert_equal 3, result.each.size
    end

    test "cast_values returns rows after type casting" do
      values = [["1.1", "2.2"], ["3.3", "4.4"]]
      columns = ["col1", "col2"]
      types = { "col1" => Type::Integer.new, "col2" => Type::Float.new }
      result = Result.new(columns, values, types)

      assert_equal [[1, 2.2], [3, 4.4]], result.cast_values
    end

    test "cast_values uses identity type for unknown types" do
      values = [["1.1", "2.2"], ["3.3", "4.4"]]
      columns = ["col1", "col2"]
      types = { "col1" => Type::Integer.new }
      result = Result.new(columns, values, types)

      assert_equal [[1, "2.2"], [3, "4.4"]], result.cast_values
    end

    test "cast_values returns single dimensional array if single column" do
      values = [["1.1"], ["3.3"]]
      columns = ["col1"]
      types = { "col1" => Type::Integer.new }
      result = Result.new(columns, values, types)

      assert_equal [1, 3], result.cast_values
    end

    test "cast_values can receive types to use instead" do
      values = [["1.1", "2.2"], ["3.3", "4.4"]]
      columns = ["col1", "col2"]
      types = { "col1" => Type::Integer.new, "col2" => Type::Float.new }
      result = Result.new(columns, values, types)

      assert_equal [[1.1, 2.2], [3.3, 4.4]], result.cast_values("col1" => Type::Float.new)
    end
  end
end
