# frozen_string_literal: true

require "cases/helper"

class QuotingTest < ActiveRecord::AbstractMysqlTestCase
  def setup
    super
    @conn = ActiveRecord::Base.connection
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

  def test_cast_bound_duration
    expected = assert_deprecated(ActiveRecord.deprecator) { @conn.cast_bound_value(42.seconds) }
    assert_equal "42", expected
  end

  def test_cast_bound_true
    assert_equal "1", @conn.cast_bound_value(true)
  end

  def test_cast_bound_false
    assert_equal "0", @conn.cast_bound_value(false)
  end

  def test_quote_bound_integer
    expected = assert_deprecated(ActiveRecord.deprecator) { @conn.quote_bound_value(42) }
    assert_equal "'42'", expected
  end

  def test_quote_bound_big_decimal
    expected = assert_deprecated(ActiveRecord.deprecator) { @conn.quote_bound_value(BigDecimal("4.2")) }
    assert_equal "'4.2'", expected
  end

  def test_quote_bound_rational
    expected = assert_deprecated(ActiveRecord.deprecator) { @conn.quote_bound_value(Rational(3, 4)) }
    assert_equal "'0.75'", expected
  end

  def test_quote_bound_duration
    expected = assert_deprecated(ActiveRecord.deprecator) { @conn.quote_bound_value(42.seconds) }
    assert_equal "'42'", expected
  end

  def test_quote_bound_true
    expected = assert_deprecated(ActiveRecord.deprecator) { @conn.quote_bound_value(true) }
    assert_equal "'1'", expected
  end

  def test_quote_bound_false
    expected = assert_deprecated(ActiveRecord.deprecator) { @conn.quote_bound_value(false) }
    assert_equal "'0'", expected
  end
end
