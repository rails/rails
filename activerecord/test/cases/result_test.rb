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

    test "length" do
      assert_equal 3, result.length
    end

    test "to_hash returns row_hashes" do
      assert_equal [
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" },
        { "col_1" => "row 2 col 1", "col_2" => "row 2 col 2" },
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" },
      ], result.to_hash
    end

    test "first returns first row as a hash" do
      assert_equal(
        { "col_1" => "row 1 col 1", "col_2" => "row 1 col 2" }, result.first)
    end

    test "last returns last row as a hash" do
      assert_equal(
        { "col_1" => "row 3 col 1", "col_2" => "row 3 col 2" }, result.last)
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

    test "cast_values! returns rows after type casting" do
       values = [["1.1", "2.2"], ["3.3", "4.4"]]
       columns = ["col1", "col2"]
       types = { "col1" => Type::Integer.new, "col2" => Type::Float.new }
       result = Result.new(columns, values, types)

       assert_equal [[1, 2.2], [3, 4.4]], result.cast_values!
     end

     test "cast_values! can receive types to use instead" do
       values = [["1.1", "2.2"], ["3.3", "4.4"]]
       columns = ["col1", "col2"]
       types = { "col1" => Type::Integer.new, "col2" => Type::Float.new }
       result = Result.new(columns, values, types)

       assert_equal [[1.1, 2.2], [3.3, 4.4]], result.cast_values!("col1" => Type::Float.new)
     end

     test "cast_values! overwrites rows attribute" do
       values = [["1.1", "2.2"], ["3.3", "4.4"]]
       columns = ["col1", "col2"]
       types = { "col1" => Type::Integer.new, "col2" => Type::Float.new }
       result = Result.new(columns, values, types)
       result.cast_values!

       assert_equal [[1, 2.2], [3, 4.4]], result.rows
     end

     test "cast_values! clears hash_rows memoziation cache" do
       columns = ["col1"]
       values = [["row_1 col_1"]]
       result = Result.new(columns, values)
       result.to_hash
       result.cast_values!

       assert_nil result.instance_variable_get("@hash_rows")
     end
  end
end
