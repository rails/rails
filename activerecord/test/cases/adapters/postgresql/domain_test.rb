# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

class PostgresqlDomainTest < ActiveRecord::PostgreSQLTestCase
  include ConnectionHelper

  class PostgresqlDomain < ActiveRecord::Base
    self.table_name = "postgresql_domains"
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.execute "CREATE DOMAIN custom_money as numeric(8,2)"
      @connection.create_table("postgresql_domains") do |t|
        t.column :price, :custom_money
      end
    end
  end

  teardown do
    @connection.drop_table "postgresql_domains", if_exists: true
    @connection.execute "DROP DOMAIN IF EXISTS custom_money"
    reset_connection
  end

  def test_column
    column = PostgresqlDomain.columns_hash["price"]
    assert_equal :decimal, column.type
    assert_equal "custom_money", column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlDomain.type_for_attribute("price")
    assert_not_predicate type, :binary?
  end

  def test_domain_acts_like_basetype
    PostgresqlDomain.create price: ""
    record = PostgresqlDomain.first
    assert_nil record.price

    record.price = "34.15"
    record.save!

    assert_equal BigDecimal("34.15"), record.reload.price
  end
end
