# frozen_string_literal: true

require 'cases/helper'

class Mysql2SqlTypesTest < ActiveRecord::Mysql2TestCase
  def test_binary_types
    assert_equal 'varbinary(64)', type_to_sql(:binary, 64)
    assert_equal 'varbinary(4095)', type_to_sql(:binary, 4095)
    assert_equal 'blob', type_to_sql(:binary, 4096)
    assert_equal 'blob', type_to_sql(:binary)
  end

  def type_to_sql(type, limit = nil)
    ActiveRecord::Base.connection.type_to_sql(type, limit: limit)
  end
end
