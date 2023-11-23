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

  def test_cast_bound_true
    assert_equal "1", @conn.cast_bound_value(true)
  end

  def test_cast_bound_false
    assert_equal "0", @conn.cast_bound_value(false)
  end
end
