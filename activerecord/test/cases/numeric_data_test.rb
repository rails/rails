# frozen_string_literal: true

require "cases/helper"
require "models/numeric_data"

class NumericDataTest < ActiveRecord::TestCase
  def test_big_decimal_conditions
    m = NumericData.new(
      bank_balance: 1586.43,
      big_bank_balance: BigDecimal("1000234000567.95"),
      world_population: 6000000000,
      my_house_population: 3
    )
    assert m.save
    assert_equal 0, NumericData.where("bank_balance > ?", 2000.0).count
  end

  def test_numeric_fields
    m = NumericData.new(
      bank_balance: 1586.43,
      big_bank_balance: BigDecimal("1000234000567.95"),
      world_population: 6000000000,
      my_house_population: 3
    )
    assert m.save

    m1 = NumericData.find(m.id)
    assert_not_nil m1

    # As with migration_test.rb, we should make world_population >= 2**62
    # to cover 64-bit platforms and test it is a Bignum, but the main thing
    # is that it's an Integer.
    assert_kind_of Integer, m1.world_population
    assert_equal 6000000000, m1.world_population

    assert_kind_of Integer, m1.my_house_population
    assert_equal 3, m1.my_house_population

    assert_kind_of BigDecimal, m1.bank_balance
    assert_equal BigDecimal("1586.43"), m1.bank_balance

    assert_kind_of BigDecimal, m1.big_bank_balance
    assert_equal BigDecimal("1000234000567.95"), m1.big_bank_balance
  end

  def test_numeric_fields_with_scale
    m = NumericData.new(
      bank_balance: 1586.43122334,
      big_bank_balance: BigDecimal("234000567.952344"),
      world_population: 6000000000,
      my_house_population: 3
    )
    assert m.save

    m1 = NumericData.find(m.id)
    assert_not_nil m1

    # As with migration_test.rb, we should make world_population >= 2**62
    # to cover 64-bit platforms and test it is a Bignum, but the main thing
    # is that it's an Integer.
    assert_kind_of Integer, m1.world_population
    assert_equal 6000000000, m1.world_population

    assert_kind_of Integer, m1.my_house_population
    assert_equal 3, m1.my_house_population

    assert_kind_of BigDecimal, m1.bank_balance
    assert_equal BigDecimal("1586.43"), m1.bank_balance

    assert_kind_of BigDecimal, m1.big_bank_balance
    assert_equal BigDecimal("234000567.95"), m1.big_bank_balance
  end
end
