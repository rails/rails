require "cases/helper"
require 'support/ddl_helper'

class Mysql2AdapterTest < ActiveRecord::Mysql2TestCase
  include DdlHelper

  def setup
    @conn = ActiveRecord::Base.connection
  end

  def test_valid_column
    with_example_table do
      column = @conn.columns('ex').find { |col| col.name == 'id' }
      assert @conn.valid_type?(column.type)
    end
  end

  def test_invalid_column
    assert_not @conn.valid_type?(:foobar)
  end

  def test_exec_insert_number
    with_example_table do
      insert(@conn, 'number' => 10)

      result = @conn.exec_query('SELECT number FROM ex WHERE number = 10')

      assert_equal 1, result.rows.length
      assert_equal 10, result.rows.last.last
    end
  end

  def test_exec_insert_string
    with_example_table do
      str = 'いただきます！'
      insert(@conn, 'number' => 10, 'data' => str)

      result = @conn.exec_query('SELECT number, data FROM ex WHERE number = 10')

      value = result.rows.last.last

      assert_equal str, value
    end
  end

  def test_composite_primary_key
    with_example_table '`id` INT, `number` INT, foo INT, PRIMARY KEY (`id`, `number`)' do
      assert_nil @conn.primary_key('ex')
    end
  end

  def test_tinyint_integer_typecasting
    with_example_table '`status` TINYINT(4)' do
      insert(@conn, { 'status' => 2 }, 'ex')

      result = @conn.exec_query('SELECT status FROM ex')

      assert_equal 2, result.last['status']
    end
  end

  def test_supports_extensions
    assert_not @conn.supports_extensions?, 'does not support extensions'
  end

  def test_respond_to_enable_extension
    assert @conn.respond_to?(:enable_extension)
  end

  def test_respond_to_disable_extension
    assert @conn.respond_to?(:disable_extension)
  end

  private

  def insert(ctx, data, table='ex')
    sql = "INSERT INTO #{table} (#{data.keys.join(', ')})
           VALUES ('#{data.values.join(%{', '})}')"

    ctx.exec_insert(sql, 'SQL', [])
  end

  def with_example_table(definition = '`id` int auto_increment PRIMARY KEY, `number` integer, `data` varchar(255)', &block)
    super(@conn, 'ex', definition, &block)
  end
end
