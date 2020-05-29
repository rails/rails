# frozen_string_literal: true

require "cases/helper"
require "models/developer"

class TableTest < ActiveRecord::TestCase
  def test_t_responds_to_column_names
    Developer.column_names.each do |name|
      assert_respond_to Developer.t, name
    end
  end

  def test_table_responds_to_column_names
    Developer.column_names.each do |name|
      assert_respond_to Developer::Table, name
    end
  end

  def test_table_is_arel_attribute
    assert_kind_of Arel::Attributes::Attribute, Developer::Table.id
  end
end
