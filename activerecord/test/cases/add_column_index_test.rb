# frozen_string_literal: true

require "cases/helper"

class AddColumnIndexTest < ActiveRecord::TestCase
  INDEX_KWARG_WARNING = <<~WARNING
    WARNING: #add_column ignores the :index keyword argument.

    To create an index, use #add_index.
  WARNING

  setup do
    @connection = ActiveRecord::Base.connection

    @connection.create_table("add_column_tests", force: true) do |t|
      t.string "name"
    end
  end

  teardown do
    @connection.drop_table "add_column_tests", if_exists: true
  end

  def test_no_index_kwarg
    warning = capture(:stderr) do
      @connection.add_column :add_column_tests, :height, :integer
    end
    assert_no_match(INDEX_KWARG_WARNING, warning)
  end

  def test_index_true_kwarg
    warning = capture(:stderr) do
      @connection.add_column :add_column_tests, :height, :integer, index: true
    end
    assert_match(INDEX_KWARG_WARNING, warning)
  end

  def test_index_false_kwarg
    warning = capture(:stderr) do
      @connection.add_column :add_column_tests, :height, :integer, index: false
    end
    assert_match(INDEX_KWARG_WARNING, warning)
  end
end
