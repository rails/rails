# encoding: utf-8
require "cases/helper"
require 'models/owner'

module ActiveRecord
  module ConnectionAdapters
    class SQLite3AdapterTest < ActiveRecord::TestCase
      self.use_transactional_fixtures = false

      class DualEncoding < ActiveRecord::Base
      end

      def setup
        @conn = Base.sqlite3_connection :database => ':memory:',
                                       :adapter => 'sqlite3',
                                       :timeout => 100
        @conn.execute <<-eosql
          CREATE TABLE items (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          )
        eosql

        @conn.extend(LogIntercepter)
        @conn.intercepted = true
      end

      def test_valid_column
        column = @conn.column('items').find { |col| col.name == 'id' }
        assert @conn.valid_type?(column.type)
      end

      def test_invalid_column
        assert @conn.valid_type?(:foobar)
      end

      def teardown
        @conn.intercepted = false
        @conn.logged = []
      end

      def test_column_types
        owner = Owner.create!(:name => "hello".encode('ascii-8bit'))
        owner.reload
        select = Owner.columns.map { |c| "typeof(#{c.name})" }.join ', '
        result = Owner.connection.exec_query <<-esql
          SELECT #{select}
          FROM   #{Owner.table_name}
          WHERE  #{Owner.primary_key} = #{owner.id}
        esql

        assert(!result.rows.first.include?("blob"), "should not store blobs")
      end

      def test_exec_insert
        column = @conn.columns('items').find { |col| col.name == 'number' }
        vals   = [[column, 10]]
        @conn.exec_insert('insert into items (number) VALUES (?)', 'SQL', vals)

        result = @conn.exec_query(
          'select number from items where number = ?', 'SQL', vals)

        assert_equal 1, result.rows.length
        assert_equal 10, result.rows.first.first
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
        bind_param = @conn.substitute_at('foo', 0)
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

      def test_quote_binary_column_escapes_it
        DualEncoding.connection.execute(<<-eosql)
          CREATE TABLE dual_encodings (
            id integer PRIMARY KEY AUTOINCREMENT,
            name string,
            data binary
          )
        eosql
        str = "\x80".force_encoding("ASCII-8BIT")
        binary = DualEncoding.new :name => 'いただきます！', :data => str
        binary.save!
        assert_equal str, binary.data

      ensure
        DualEncoding.connection.drop_table('dual_encodings')
      end

      def test_type_cast_should_not_mutate_encoding
        name  = 'hello'.force_encoding(Encoding::ASCII_8BIT)
        Owner.create(name: name)
        assert_equal Encoding::ASCII_8BIT, name.encoding
      end

      def test_execute
        @conn.execute "INSERT INTO items (number) VALUES (10)"
        records = @conn.execute "SELECT * FROM items"
        assert_equal 1, records.length

        record = records.first
        assert_equal 10, record['number']
        assert_equal 1, record['id']
      end

      def test_quote_string
        assert_equal "''", @conn.quote_string("'")
      end

      def test_insert_sql
        2.times do |i|
          rv = @conn.insert_sql "INSERT INTO items (number) VALUES (#{i})"
          assert_equal(i + 1, rv)
        end

        records = @conn.execute "SELECT * FROM items"
        assert_equal 2, records.length
      end

      def test_insert_sql_logged
        sql = "INSERT INTO items (number) VALUES (10)"
        name = "foo"

        assert_logged([[sql, name, []]]) do
          @conn.insert_sql sql, name
        end
      end

      def test_insert_id_value_returned
        sql = "INSERT INTO items (number) VALUES (10)"
        idval = 'vuvuzela'
        id = @conn.insert_sql sql, nil, nil, idval
        assert_equal idval, id
      end

      def test_select_rows
        2.times do |i|
          @conn.create "INSERT INTO items (number) VALUES (#{i})"
        end
        rows = @conn.select_rows 'select number, id from items'
        assert_equal [[0, 1], [1, 2]], rows
      end

      def test_select_rows_logged
        sql = "select * from items"
        name = "foo"

        assert_logged([[sql, name, []]]) do
          @conn.select_rows sql, name
        end
      end

      def test_transaction
        count_sql = 'select count(*) from items'

        @conn.begin_db_transaction
        @conn.create "INSERT INTO items (number) VALUES (10)"

        assert_equal 1, @conn.select_rows(count_sql).first.first
        @conn.rollback_db_transaction
        assert_equal 0, @conn.select_rows(count_sql).first.first
      end

      def test_tables
        assert_equal %w{ items }, @conn.tables

        @conn.execute <<-eosql
          CREATE TABLE people (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          )
        eosql
        assert_equal %w{ items people }.sort, @conn.tables.sort
      end

      def test_tables_logs_name
        assert_logged [['SCHEMA', []]] do
          @conn.tables('hello')
          assert_not_nil @conn.logged.first.shift
        end
      end

      def test_indexes_logs_name
        assert_logged [["PRAGMA index_list(\"items\")", 'SCHEMA', []]] do
          @conn.indexes('items', 'hello')
        end
      end

      def test_table_exists_logs_name
        assert @conn.table_exists?('items')
        assert_equal 'SCHEMA', @conn.logged[0][1]
      end

      def test_columns
        columns = @conn.columns('items').sort_by { |x| x.name }
        assert_equal 2, columns.length
        assert_equal %w{ id number }.sort, columns.map { |x| x.name }
        assert_equal [nil, nil], columns.map { |x| x.default }
        assert_equal [true, true], columns.map { |x| x.null }
      end

      def test_columns_with_default
        @conn.execute <<-eosql
          CREATE TABLE columns_with_default (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer default 10
          )
        eosql
        column = @conn.columns('columns_with_default').find { |x|
          x.name == 'number'
        }
        assert_equal 10, column.default
      end

      def test_columns_with_not_null
        @conn.execute <<-eosql
          CREATE TABLE columns_with_default (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer not null
          )
        eosql
        column = @conn.columns('columns_with_default').find { |x|
          x.name == 'number'
        }
        assert !column.null, "column should not be null"
      end

      def test_indexes_logs
        assert_difference('@conn.logged.length') do
          @conn.indexes('items')
        end
        assert_match(/items/, @conn.logged.last.first)
      end

      def test_no_indexes
        assert_equal [], @conn.indexes('items')
      end

      def test_index
        @conn.add_index 'items', 'id', :unique => true, :name => 'fun'
        index = @conn.indexes('items').find { |idx| idx.name == 'fun' }

        assert_equal 'items', index.table
        assert index.unique, 'index is unique'
        assert_equal ['id'], index.columns
      end

      def test_non_unique_index
        @conn.add_index 'items', 'id', :name => 'fun'
        index = @conn.indexes('items').find { |idx| idx.name == 'fun' }
        assert !index.unique, 'index is not unique'
      end

      def test_compound_index
        @conn.add_index 'items', %w{ id number }, :name => 'fun'
        index = @conn.indexes('items').find { |idx| idx.name == 'fun' }
        assert_equal %w{ id number }.sort, index.columns.sort
      end

      def test_primary_key
        assert_equal 'id', @conn.primary_key('items')

        @conn.execute <<-eosql
          CREATE TABLE foos (
            internet integer PRIMARY KEY AUTOINCREMENT,
            number integer not null
          )
        eosql
        assert_equal 'internet', @conn.primary_key('foos')
      end

      def test_no_primary_key
        @conn.execute 'CREATE TABLE failboat (number integer not null)'
        assert_nil @conn.primary_key('failboat')
      end

      private

      def assert_logged logs
        yield
        assert_equal logs, @conn.logged
      end

    end
  end
end
