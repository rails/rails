# frozen_string_literal: true

require "cases/helper"

class QuotingTest < ActiveRecord::AbstractMysqlTestCase
  def setup
    super
    @conn = ActiveRecord::Base.lease_connection
  end

  def test_cast_bound_integer
    assert_equal "42", @conn.cast_bound_value(42)
  end

  def test_cast_bound_big_decimal
    assert_equal "4.2", @conn.cast_bound_value(BigDecimal("4.2"))
  end

  def test_cast_bound_rational
    assert_equal "0.75", @conn.cast_bound_value(Rational(3, 4))
  end

  def test_cast_bound_true
    assert_equal "1", @conn.cast_bound_value(true)
  end

  def test_cast_bound_false
    assert_equal "0", @conn.cast_bound_value(false)
  end

  def test_quote_string
    assert_equal "\\'", @conn.quote_string("'")
  end

  def test_quote_column_name
    [@conn, @conn.class].each do |adapter|
      assert_equal "`foo`", adapter.quote_column_name("foo")
      assert_equal '`hel"lo`', adapter.quote_column_name(%{hel"lo})
    end
  end

  def test_quote_table_name
    [@conn, @conn.class].each do |adapter|
      assert_equal "`foo`", adapter.quote_table_name("foo")
      assert_equal "`foo`.`bar`", adapter.quote_table_name("foo.bar")
      assert_equal '`hel"lo.wol\\d`', adapter.quote_column_name('hel"lo.wol\\d')
    end
  end
end
