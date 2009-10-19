require "cases/helper"

class ObjectTest < ActiveRecord::TestCase

  def setup
    @column = ActiveRecord::ConnectionAdapters::Column.new('name', '', 'date')
    @object = ActiveRecord::Type::Object.new(@column)
  end

  test "typecast with column" do
    date = Date.new(2009, 7, 10)
    assert_equal date, @object.cast('10-07-2009')
    assert_equal nil,  @object.cast('')

    assert_equal date, @object.precast(date)
  end

  test "cast as boolean" do
    assert_equal false, @object.boolean(nil)
    assert_equal false, @object.boolean('false')
    assert_equal true,  @object.boolean('10-07-2009')
  end

end
