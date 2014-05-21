# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlByteaTest < ActiveRecord::TestCase
  class PostgresqlMoney < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.execute("set lc_monetary = 'C'")
  end

  def test_column
    column = PostgresqlMoney.columns_hash["wealth"]
    assert_equal :decimal, column.type
    assert_equal "money", column.sql_type
    assert_equal 2, column.scale
    assert column.number?
    assert_not column.text?
    assert_not column.binary?
    assert_not column.array
  end

  def test_money_values
    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (1, '567.89'::money)")
    @connection.execute("INSERT INTO postgresql_moneys (id, wealth) VALUES (2, '-567.89'::money)")

    first_money = PostgresqlMoney.find(1)
    second_money = PostgresqlMoney.find(2)
    assert_equal 567.89, first_money.wealth
    assert_equal(-567.89, second_money.wealth)
  end

  def test_money_type_cast
    column = PostgresqlMoney.columns_hash['wealth']
    assert_equal(12345678.12, column.type_cast("$12,345,678.12"))
    assert_equal(12345678.12, column.type_cast("$12.345.678,12"))
    assert_equal(-1.15, column.type_cast("-$1.15"))
    assert_equal(-2.25, column.type_cast("($2.25)"))
  end

  def test_create_and_update_money
    money = PostgresqlMoney.create(wealth: "987.65")
    assert_equal 987.65, money.wealth

    new_value = BigDecimal.new('123.45')
    money.wealth = new_value
    money.save!
    money.reload
    assert_equal new_value, money.wealth
  end
end
