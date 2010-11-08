require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::TestCase
      def setup
        @connection = ActiveRecord::Base.connection
        @connection.exec_query('drop table if exists ex')
        @connection.exec_query('create table ex(id serial primary key, data character varying(255))')
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
    end
  end
end
