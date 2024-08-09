# frozen_string_literal: true

require "cases/helper"
require "models/book"

class InsertRowsTest < ActiveRecord::TestCase
  fixtures :books

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
    @original_db_warnings_action = :ignore
  end

  def teardown
    Arel::Table.engine = ActiveRecord::Base
  end

  def test_insert_rows
    assert_difference "Book.count", +10 do
      Book.insert_rows([
        ["Rework", 1 ],
        ["Patterns of Enterprise Application Architecture", 1 ],
        ["Design of Everyday Things", 1 ],
        ["Practical Object-Oriented Design in Ruby", 1 ],
        ["Clean Code", 1 ],
        ["Ruby Under a Microscope", 1 ],
        ["The Principles of Product Development Flow", 1 ],
        ["Peopleware", 1 ],
        ["About Face", 1 ],
        ["Eloquent Ruby", 1 ],
      ], columns: %w(name author_id))
    end
  end

  def test_insert_rows_raises_error_on_duplicate_columns
    assert_raises(ArgumentError) do
      Book.insert_rows([
        ["Rework", 1, 2]
      ], columns: %w(name author_id author_id))
    end

    assert_raises(ArgumentError) do
      Book.insert_rows([
        ["Rework", 1, 2]
      ], columns: ["name", :author_id, "author_id"])
    end
  end

  def test_insert_rows_column_mode_mismatch
    assert_raises(ArgumentError) do
      Book.insert_rows([
        ["Rework", 1, 2]
      ], columns: %w(name author_id))
    end

    assert_raises(ArgumentError) do
      Book.insert_rows([
        ["Rework", 1],
        ["Rework", 1, 2]
      ], columns: %w(name author_id))
    end

    assert_raises(ArgumentError) do
      Book.insert_rows([
        ["Rework", 1],
        ["Rework", 1, 2]
      ], columns: %w(name author_id onemore))
    end
  end

  def test_insert_rows_with_arel_predicates
    sql_predicate = if current_adapter?(:SQLite3Adapter)
      "DATE('now', '+1 day')"
    elsif current_adapter?(:PostgreSQLAdapter)
      "NOW() + INTERVAL '1 DAY'"
    else
      "NOW() + INTERVAL 1 DAY"
    end

    Book.insert_rows([
      ["Rework", 1, Arel.sql(sql_predicate) ],
    ], columns: %w(name author_id updated_at))

    book = Book.find_by(name: "Rework")
    assert book.updated_at > Time.current, "expected #{book.updated_at} to be greater than #{Time.current}"
  end

  def test_insert_all_should_handle_empty_arrays
    skip unless supports_insert_on_duplicate_update?

    assert_empty Book.insert_rows([], columns: %w(name author_id))
  end

  def test_insert_all_returns_ActiveRecord_Result
    result = Book.insert_rows [ [ "Rework", 1 ]], columns: %w(name author_id)
    assert_kind_of ActiveRecord::Result, result
  end

  def test_insert_all_returns_primary_key_if_returning_is_supported
    skip unless supports_insert_returning?

    result = Book.insert_rows [ [ "Rework", 1 ]], columns: %w(name author_id)
    assert_equal %w[ id ], result.columns
  end

  def test_insert_all_returns_nothing_if_returning_is_empty
    skip unless supports_insert_returning?

    result = Book.insert_rows [ [ "Rework", 1 ]], columns: %w(name author_id), returning: []
    assert_equal [], result.columns
  end

  def test_insert_all_returns_nothing_if_returning_is_false
    skip unless supports_insert_returning?

    result = Book.insert_rows [ [ "Rework", 1 ]], columns: %w(name author_id), returning: false
    assert_equal [], result.columns
  end

  def test_insert_all_returns_requested_fields
    skip unless supports_insert_returning?

    result = Book.insert_rows [ [ "Rework", 1 ]], columns: %w(name author_id), returning: [:id, :name]
    assert_equal %w[ Rework ], result.pluck("name")
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_insert_all_when_table_name_contains_database
      database_name = Book.connection_db_config.database
      Book.table_name = "#{database_name}.books"

      assert_nothing_raised do
        Book.insert_rows [ [ "Rework", 1 ]], columns: %w(name author_id)
      end
    ensure
      Book.table_name = "books"
    end
  end
end
