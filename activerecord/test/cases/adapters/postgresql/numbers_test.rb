# frozen_string_literal: true

require 'cases/helper'

class PostgresqlNumberTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlNumber < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_numbers', force: true) do |t|
      t.column 'single', 'REAL'
      t.column 'double', 'DOUBLE PRECISION'
    end
  end

  teardown do
    @connection.drop_table 'postgresql_numbers', if_exists: true
  end

  def test_data_type
    assert_equal :float, PostgresqlNumber.columns_hash['single'].type
    assert_equal :float, PostgresqlNumber.columns_hash['double'].type
  end

  def test_values
    @connection.execute('INSERT INTO postgresql_numbers (id, single, double) VALUES (1, 123.456, 123456.789)')
    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (2, '-Infinity', 'Infinity')")
    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (3, 123.456, 'NaN')")

    first, second, third = PostgresqlNumber.find(1, 2, 3)

    assert_equal 123.456, first.single
    assert_equal 123456.789, first.double
    assert_equal(-::Float::INFINITY, second.single)
    assert_equal ::Float::INFINITY, second.double
    assert third.double.nan?, "Expected #{third.double} to be NaN"
  end

  def test_update
    record = PostgresqlNumber.create! single: '123.456', double: '123456.789'
    new_single = 789.012
    new_double = 789012.345
    record.single = new_single
    record.double = new_double
    record.save!

    record.reload
    assert_equal new_single, record.single
    assert_equal new_double, record.double
  end
end
