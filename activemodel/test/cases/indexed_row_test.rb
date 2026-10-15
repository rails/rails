# frozen_string_literal: true

require "cases/helper"

class IndexedRowTest < ActiveModel::TestCase
  setup do
    @hash = { "first_name" => "George", "last_name" => "Abitbol", "age" => 42 }.freeze
    @row = ActiveModel::IndexedRow[@hash]
  end

  test ".build_indexes" do
    assert_equal({ a: 0, b: 1, c: 2, d: 3 }, ActiveModel::IndexedRow.build_indexes(%i(a b c d)))
    assert_equal({ a: 0, b: 5, c: 2, d: 6 }, ActiveModel::IndexedRow.build_indexes(%i(a b c b b b d)))
  end

  test "#[]" do
    assert_equal "George", @row["first_name"]
    assert_equal "Abitbol", @row["last_name"]
    assert_equal 42, @row["age"]
    assert_nil @row["missing"]
  end

  test "#at" do
    assert_equal "George", @row.at(0)
    assert_equal "Abitbol", @row.at(1)
    assert_equal 42, @row.at(2)
    assert_nil @row.at(3)
  end

  test "#fetch_at" do
    assert_equal "George", @row.fetch_at(0)
    assert_equal 42, @row.fetch_at(2)
    assert_equal :missing, @row.fetch_at(3) { :missing }
    error = assert_raises(KeyError) { @row.fetch_at(3) }
    assert_equal "index not found: 3", error.message
  end

  test "#at and #fetch_at treat unset slots as missing" do
    values = ActiveModel::IndexedRow.unset_row(3)
    values[0] = 1
    values[2] = nil
    row = ActiveModel::IndexedRow.new({ "id" => 0, "name" => 1, "age" => 2 }, values.freeze)

    assert_equal 1, row.at(0)
    assert_nil row.at(1)
    assert_nil row.at(2)
    assert_equal :missing, row.fetch_at(1) { :missing }
    assert_nil row.fetch_at(2) { :missing }
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

  test "#values_at" do
    assert_equal @hash.values_at("age", "first_name", "missing"), @row.values_at("age", "first_name", "missing")
  end

  test "#==" do
    assert_equal @hash, @row
  end

  test "#hash" do
    assert_equal 1, [@row, @row.dup].uniq.size
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

  test "#at and #fetch_at" do
    assert_nil @row.at(0)
    assert_equal :missing, @row.fetch_at(0) { :missing }
    assert_raises(KeyError) { @row.fetch_at(0) }

    @row["first_name"] = "George"
    assert_equal "George", @row.at(0)
    assert_equal "George", @row.fetch_at(0)
    assert_nil @row.at(1)
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

  test "#values_at" do
    assert_equal [nil, nil], @row.values_at("age", "first_name")
    @row["age"] = 42
    assert_equal [42, nil, nil], @row.values_at("age", "first_name", "missing")
  end

  test "#fetch" do
    assert_raises(KeyError) { @row.fetch("age") }
    assert_equal(4, @row.fetch("age") { 4 })
    @row["age"] = 42
    assert_equal 42, @row.fetch("age")

    assert_raises(KeyError) { @row.fetch("missing") }
    assert_equal(5, @row.fetch("missing") { 5 })
  end

  test "built from a row with duplicated columns" do
    columns = ["id", "name", "id"].freeze
    reference = ActiveModel::IndexedRow.new(ActiveModel::IndexedRow.build_indexes(columns), [1, "George", 1].freeze)
    row = reference.new_empty_mutable_row

    assert_raises(KeyError) { row.fetch("id") }
    assert_equal(4, row.fetch("id") { 4 })
    assert_equal false, row.key?("id")
    assert_equal [], row.keys
    assert_equal 0, row.size

    row["id"] = 42
    assert_equal 42, row.fetch("id")
    assert_equal 1, row.size
    assert_equal ["id"], row.keys
  end

  test "built from an empty row" do
    row = ActiveModel::IndexedRow[{}].new_empty_mutable_row

    assert_equal 0, row.size
    assert_equal 0, row.length
    assert_equal [], row.keys
    assert_equal [], row.values
    assert_equal({}, row.to_h)
    assert_raises(KeyError) { row.fetch("id") }
  end

  test "built from a row with only duplicated columns" do
    columns = ["id", "id", "id"].freeze
    reference = ActiveModel::IndexedRow.new(ActiveModel::IndexedRow.build_indexes(columns), [1, 2, 3].freeze)
    row = reference.new_empty_mutable_row

    assert_equal 3, reference.fetch("id")
    assert_same reference.indexes, row.indexes
    assert_equal 0, row.size
    assert_raises(KeyError) { row.fetch("id") }

    row["id"] = nil
    assert_nil row.fetch("id") { flunk "nil is a set value" }
    assert row.key?("id")
    assert_equal 1, row.size
    assert_equal 1, row.length
    assert_equal ["id"], row.keys
    assert_equal [nil], row.values

    row["id"] = false
    assert_equal false, row.fetch("id")
    assert_equal 1, row.size
    assert_equal({ "id" => false }, row.to_h)

    empty_row = row.new_empty_mutable_row
    assert_same row.indexes, empty_row.indexes
    assert_equal 0, empty_row.size
    assert_raises(KeyError) { empty_row.fetch("id") }
  end
end

class RemapperTest < ActiveModel::TestCase
  test "#build" do
    row = ActiveModel::IndexedRow["_first_name" => "George", "_last_name" => "Abitbol", "_age" => 42]
    remapper = ActiveModel::IndexedRow::Remapper.new(
      row.indexes,
      %w(_age _first_name),
      %w(age name),
    )
    remapped_row = remapper.build(row)
    assert_equal({ "age" => 42, "name" => "George" }, remapped_row.to_h)
  end

  test "#build with duplicated keys" do
    columns = ["id", "author_id", "name", "author_id"].freeze
    values = [1, 2, "George", 4].freeze
    indexes = ActiveModel::IndexedRow.build_indexes(columns)
    row = ActiveModel::IndexedRow.new(indexes, values)

    remapper = ActiveModel::IndexedRow::Remapper.new(
      row.indexes,
      ["author_id", "name", "author_id"],
      ["author_id", "first_name", "author_id"],
    )
    remapped_row = remapper.build(row)
    assert_equal row["author_id"], remapped_row["author_id"]
    assert_equal row["name"], remapped_row["first_name"]

    assert_equal(2, remapped_row.values.size)
  end

  Column = Struct.new(:ord)

  test "#build with a column map lays the row out by ord" do
    row = ActiveModel::IndexedRow["t0_r0" => 1, "t0_r1" => "George", "t0_r2" => 42]
    column_map = { "id" => Column.new(0), "age" => Column.new(1), "name" => Column.new(2) }.freeze
    remapper = ActiveModel::IndexedRow::Remapper.new(
      row.indexes,
      %w(t0_r0 t0_r1 t0_r2),
      %w(id name age),
      column_map,
    )
    remapped_row = remapper.build(row)

    assert_same column_map, remapped_row.indexes
    assert_equal [1, 42, "George"], remapped_row.row
    assert_equal({ "id" => 1, "age" => 42, "name" => "George" }, remapped_row.to_h)
  end

  test "#build with a column map leaves unselected columns unset" do
    row = ActiveModel::IndexedRow["t0_r0" => 1, "t0_r1" => "George"]
    column_map = { "id" => Column.new(0), "age" => Column.new(1), "name" => Column.new(2) }.freeze
    remapper = ActiveModel::IndexedRow::Remapper.new(
      row.indexes,
      %w(t0_r0 t0_r1),
      %w(id name),
      column_map,
    )
    remapped_row = remapper.build(row)

    assert_not remapped_row.key?("age")
    assert_equal :missing, remapped_row.fetch("age") { :missing }
    assert_equal({ "id" => 1, "name" => "George" }, remapped_row.to_h)
  end

  test "#build with a column map adds unknown columns after the last ord" do
    row = ActiveModel::IndexedRow["t0_r0" => 1, "extra" => "x"]
    column_map = { "id" => Column.new(0), "name" => Column.new(2) }.freeze
    remapper = ActiveModel::IndexedRow::Remapper.new(
      row.indexes,
      %w(t0_r0 extra),
      %w(id extra),
      column_map,
    )
    remapped_row = remapper.build(row)

    assert_instance_of ActiveModel::IndexedRow::ExtendedIndexes, remapped_row.indexes
    assert_equal "x", remapped_row.row[3]
    assert_equal({ "id" => 1, "extra" => "x" }, remapped_row.to_h)
    assert_equal 2, column_map.size
  end
end
