require "cases/helper"

class Mysql2EnumTest < ActiveRecord::Mysql2TestCase
  class EnumTest < ActiveRecord::Base
  end

  def test_enum_limit
    column = EnumTest.columns_hash["enum_column"]
    assert_equal 8, column.limit
  end

  def test_should_not_be_blob_or_text_column
    column = EnumTest.columns_hash["enum_column"]
    assert_not column.blob_or_text_column?
  end

  def test_should_not_be_unsigned
    column = EnumTest.columns_hash["enum_column"]
    assert_not column.unsigned?
  end

  def test_should_not_be_bigint
    column = EnumTest.columns_hash["enum_column"]
    assert_not column.bigint?
  end
end
