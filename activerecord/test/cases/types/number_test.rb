require "cases/helper"

class NumberTest < ActiveRecord::TestCase

  def setup
    @column = ActiveRecord::ConnectionAdapters::Column.new('comments_count', 0, 'integer')
    @number = ActiveRecord::Type::Number.new(@column)
  end

  test "typecast" do
    assert_equal 1, @number.cast(1)
    assert_equal 1, @number.cast('1')
    assert_equal 0, @number.cast('')

    assert_equal 0,   @number.precast(false)
    assert_equal 1,   @number.precast(true)
    assert_equal nil, @number.precast('')
    assert_equal 0,   @number.precast(0)
  end

  test "cast as boolean" do
    assert_equal true, @number.boolean('1')
    assert_equal true, @number.boolean(1)

    assert_equal false, @number.boolean(0)
    assert_equal false, @number.boolean('0')
    assert_equal false, @number.boolean(nil)
  end

end
