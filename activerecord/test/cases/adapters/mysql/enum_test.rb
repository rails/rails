require "cases/helper"

class MysqlEnumTest < ActiveRecord::TestCase
  class EnumTest < ActiveRecord::Base
  end

  def test_enum_limit
    assert_equal 5, EnumTest.columns.first.limit
  end
end
