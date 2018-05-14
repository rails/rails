# frozen_string_literal: true

require "cases/helper"

class Mysql2EnumTest < ActiveRecord::Mysql2TestCase
  class EnumTest < ActiveRecord::Base
  end

  def test_enum_limit
    column = EnumTest.columns_hash["enum_column"]
    assert_equal 8, column.limit
  end

  def test_should_not_be_unsigned
    column = EnumTest.columns_hash["enum_column"]
    assert_not_predicate column, :unsigned?
  end

  def test_should_not_be_bigint
    column = EnumTest.columns_hash["enum_column"]
    assert_not_predicate column, :bigint?
  end
end
