require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::TestCase
      def setup
        @connection = ActiveRecord::Base.connection
        @connection.exec('drop table if exists ex')
        @connection.exec('create table ex(id serial primary key, data character varying(255))')
      end

      def test_table_alias_length
        assert_nothing_raised do
          @connection.table_alias_length
        end
      end

      def test_exec_no_binds
        result = @connection.exec('SELECT id, data FROM ex')
        assert_equal 0, result.rows.length
        assert_equal 2, result.columns.length
        assert_equal %w{ id data }, result.columns

        string = @connection.quote('foo')
        @connection.exec("INSERT INTO ex (id, data) VALUES (1, #{string})")
        result = @connection.exec('SELECT id, data FROM ex')
        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [['1', 'foo']], result.rows
      end
    end
  end
end
