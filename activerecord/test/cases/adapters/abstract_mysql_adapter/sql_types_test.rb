# frozen_string_literal: true

require "cases/helper"

class SqlTypesTest < ActiveRecord::AbstractMysqlTestCase
  def test_binary_types
    assert_equal "varbinary(64)", type_to_sql(:binary, 64)
    assert_equal "varbinary(4095)", type_to_sql(:binary, 4095)
    assert_equal "blob", type_to_sql(:binary, 4096)
    assert_equal "blob", type_to_sql(:binary)
  end

  def type_to_sql(type, limit = nil)
    ActiveRecord::Base.lease_connection.type_to_sql(type, limit: limit)
  end
end
