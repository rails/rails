# frozen_string_literal: true

require "cases/helper"

class Mysql2QuotingTest < ActiveRecord::Mysql2TestCase
  def setup
    super
    @conn = ActiveRecord::Base.connection
  end

  def test_quote_bound_integer
    assert_equal "'42'", @conn.quote_bound_value(42)
  end

  def test_quote_bound_big_decimal
    assert_equal "'4.2'", @conn.quote_bound_value(BigDecimal("4.2"))
  end

  def test_quote_bound_rational
    assert_equal "'0.75'", @conn.quote_bound_value(Rational(3, 4))
  end

  def test_quote_bound_duration
    expected = assert_deprecated { @conn.quote_bound_value(42.seconds) }
    assert_equal "'42'", expected
  end

  def test_quote_bound_true
    assert_equal "'1'", @conn.quote_bound_value(true)
  end

  def test_quote_bound_false
    assert_equal "'0'", @conn.quote_bound_value(false)
  end
end
