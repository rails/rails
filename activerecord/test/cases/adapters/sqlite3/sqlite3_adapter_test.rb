require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3AdapterTest < ActiveRecord::TestCase
      def setup
        @conn = Base.sqlite3_connection :database => ':memory:',
                                       :adapter => 'sqlite3',
                                       :timeout => 100
      end

      def test_primary_key_returns_nil_for_no_pk
        @conn.exec_query('create table ex(id int, data string)')
        assert_nil @conn.primary_key('ex')
      end

      def test_connection_no_db
        assert_raises(ArgumentError) do
          Base.sqlite3_connection {}
        end
      end

      def test_connection_no_adapter
        assert_raises(ArgumentError) do
          Base.sqlite3_connection :database => ':memory:'
        end
      end

      def test_connection_wrong_adapter
        assert_raises(ArgumentError) do
          Base.sqlite3_connection :database => ':memory:',:adapter => 'vuvuzela'
        end
      end

      def test_bad_timeout
        assert_raises(TypeError) do
          Base.sqlite3_connection :database => ':memory:',
                                  :adapter => 'sqlite3',
                                  :timeout => 'usa'
        end
      end

      # connection is OK with a nil timeout
      def test_nil_timeout
        conn = Base.sqlite3_connection :database => ':memory:',
                                       :adapter => 'sqlite3',
                                       :timeout => nil
        assert conn, 'made a connection'
      end

      def test_connect
        assert @conn, 'should have connection'
      end

      # sqlite3 defaults to UTF-8 encoding
      def test_encoding
        assert_equal 'UTF-8', @conn.encoding
      end

      def test_bind_value_substitute
        bind_param = @conn.substitute_for('foo', [])
        assert_equal Arel.sql('?'), bind_param
      end

      def test_exec_no_binds
        @conn.exec_query('create table ex(id int, data string)')
        result = @conn.exec_query('SELECT id, data FROM ex')
        assert_equal 0, result.rows.length
        assert_equal 2, result.columns.length
        assert_equal %w{ id data }, result.columns

        @conn.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')
        result = @conn.exec_query('SELECT id, data FROM ex')
        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [[1, 'foo']], result.rows
      end

      def test_exec_query_with_binds
        @conn.exec_query('create table ex(id int, data string)')
        @conn.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')
        result = @conn.exec_query(
          'SELECT id, data FROM ex WHERE id = ?', nil, [[nil, 1]])

        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [[1, 'foo']], result.rows
      end

      def test_exec_query_typecasts_bind_vals
        @conn.exec_query('create table ex(id int, data string)')
        @conn.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')
        column = @conn.columns('ex').find { |col| col.name == 'id' }

        result = @conn.exec_query(
          'SELECT id, data FROM ex WHERE id = ?', nil, [[column, '1-fuu']])

        assert_equal 1, result.rows.length
        assert_equal 2, result.columns.length

        assert_equal [[1, 'foo']], result.rows
      end
    end
  end
end
