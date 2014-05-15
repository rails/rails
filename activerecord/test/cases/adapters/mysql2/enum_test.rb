require "cases/helper"

class Mysql2EnumTest < ActiveRecord::TestCase
  class EnumTest < ActiveRecord::Base
  end

  def test_enum_limit
    assert_equal 6, EnumTest.columns.first.limit
  end
end
