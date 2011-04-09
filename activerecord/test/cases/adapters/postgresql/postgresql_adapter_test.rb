# encoding: utf-8
require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::TestCase
      def setup
        @connection = ActiveRecord::Base.connection
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(id serial primary key, number integer, data character varying(255))')
      end

      def test_exec_insert_number
        insert(@connection, 'number' => 10)

        result = @connection.exec_query('SELECT number FROM ex WHERE number = 10')

        assert_equal 1, result.rows.length
        assert_equal "10", result.rows.last.last
      end

      def test_exec_insert_string
        str = 'いただきます！'
        insert(@connection, 'number' => 10, 'data' => str)

        result = @connection.exec_query('SELECT number, data FROM ex WHERE number = 10')

        value = result.rows.last.last

        assert_equal str, value
      end

      def test_table_alias_length
        assert_nothing_raised do
          @connection.table_alias_length
        end
      end

      def test_exec_no_binds
        result = @connection.exec_query('SELECT id, data FROM ex')
        assert_equal 0, result.rows.length
        assert_equal 2, result.columns.length
        assert_equal %w{ id data }, result.columns

        string = @connection.quote('foo')
        @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")
        result = @connection.exec_query('SELECT id, data FROM ex')
        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [['1', 'foo']], result.rows
      end

      def test_exec_with_binds
        string = @connection.quote('foo')
        @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")
        result = @connection.exec_query(
          'SELECT id, data FROM ex WHERE id = $1', nil, [[nil, 1]])

        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [['1', 'foo']], result.rows
      end

      def test_exec_typecasts_bind_vals
        string = @connection.quote('foo')
        @connection.exec_query("INSERT INTO ex (id, data) VALUES (1, #{string})")

        column = @connection.columns('ex').find { |col| col.name == 'id' }
        result = @connection.exec_query(
          'SELECT id, data FROM ex WHERE id = $1', nil, [[column, '1-fuu']])

        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [['1', 'foo']], result.rows
      end

      def test_substitute_for
        bind = @connection.substitute_for(nil, [])
        assert_equal Arel.sql('$1'), bind

        bind = @connection.substitute_for(nil, [nil])
        assert_equal Arel.sql('$2'), bind
      end

      private
      def insert(ctx, data)
        binds   = data.map { |name, value|
          [ctx.columns('ex').find { |x| x.name == name }, value]
        }
        columns = binds.map(&:first).map(&:name)

        bind_subs = columns.length.times.map { |x| "$#{x + 1}" }

        sql = "INSERT INTO ex (#{columns.join(", ")})
               VALUES (#{bind_subs.join(', ')})"

        ctx.exec_insert(sql, 'SQL', binds)
      end
    end
  end
end
