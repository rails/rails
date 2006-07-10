require 'abstract_unit'

class PostgresqlDatatype < ActiveRecord::Base
end

class PGDataTypeTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  TABLE_NAME = 'postgresql_datatypes'
  COLUMNS = [
    'id SERIAL PRIMARY KEY',
    'commission_by_quarter INTEGER[]',
    'nicknames TEXT[]'
  ]

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute "CREATE TABLE #{TABLE_NAME} (#{COLUMNS.join(',')})"
    @connection.execute "INSERT INTO #{TABLE_NAME} (commission_by_quarter, nicknames) VALUES ( '{35000,21000,18000,17000}', '{foo,bar,baz}' )"
    @first = PostgresqlDatatype.find( 1 )
  end

  def teardown
    @connection.execute "DROP TABLE #{TABLE_NAME}"
  end

  def test_data_type_of_array_types
    assert_equal :string, @first.column_for_attribute("commission_by_quarter").type
    assert_equal :string, @first.column_for_attribute("nicknames").type
  end

  def test_array_values
    assert_equal '{35000,21000,18000,17000}', @first.commission_by_quarter
    assert_equal '{foo,bar,baz}', @first.nicknames
  end

  def test_update_integer_array
    new_value = '{32800,95000,29350,17000}'
    assert @first.commission_by_quarter = new_value
    assert @first.save
    assert @first.reload
    assert_equal @first.commission_by_quarter, new_value
  end

  def test_update_text_array
    new_value = '{robby,robert,rob,robbie}'
    assert @first.nicknames = new_value
    assert @first.save
    assert @first.reload
    assert_equal @first.nicknames, new_value
  end
end
