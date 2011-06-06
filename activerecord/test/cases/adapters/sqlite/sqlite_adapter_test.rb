# encoding: utf-8
require "cases/helper"
require 'models/binary'

module ActiveRecord
  module ConnectionAdapters
    class SQLiteAdapterTest < ActiveRecord::TestCase
      class DualEncoding < ActiveRecord::Base
      end

      def setup
        @ctx = Base.sqlite3_connection :database => ':memory:',
                                      :adapter => 'sqlite3',
                                      :timeout => nil
        @ctx.execute <<-eosql
          CREATE TABLE items (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          )
        eosql
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
      end

      def test_execute
        @ctx.execute "INSERT INTO items (number) VALUES (10)"
        records = @ctx.execute "SELECT * FROM items"
        assert_equal 1, records.length

        record = records.first
        assert_equal 10, record['number']
        assert_equal 1, record['id']
      end

      def test_quote_string
        assert_equal "''", @ctx.quote_string("'")
      end

      def test_insert_sql
        2.times do |i|
          rv = @ctx.insert_sql "INSERT INTO items (number) VALUES (#{i})"
          assert_equal(i + 1, rv)
        end

        records = @ctx.execute "SELECT * FROM items"
        assert_equal 2, records.length
      end

      def test_insert_sql_logged
        sql = "INSERT INTO items (number) VALUES (10)"
        name = "foo"

        assert_logged([[sql, name]]) do
          @ctx.insert_sql sql, name
        end
      end

      def test_insert_id_value_returned
        sql = "INSERT INTO items (number) VALUES (10)"
        idval = 'vuvuzela'
        id = @ctx.insert_sql sql, nil, nil, idval
        assert_equal idval, id
      end

      def test_select_rows
        2.times do |i|
          @ctx.create "INSERT INTO items (number) VALUES (#{i})"
        end
        rows = @ctx.select_rows 'select number, id from items'
        assert_equal [[0, 1], [1, 2]], rows
      end

      def test_select_rows_logged
        sql = "select * from items"
        name = "foo"

        assert_logged([[sql, name]]) do
          @ctx.select_rows sql, name
        end
      end

      def test_transaction
        count_sql = 'select count(*) from items'

        @ctx.begin_db_transaction
        @ctx.create "INSERT INTO items (number) VALUES (10)"

        assert_equal 1, @ctx.select_rows(count_sql).first.first
        @ctx.rollback_db_transaction
        assert_equal 0, @ctx.select_rows(count_sql).first.first
      end

      def test_tables
        assert_equal %w{ items }, @ctx.tables

        @ctx.execute <<-eosql
          CREATE TABLE people (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          )
        eosql
        assert_equal %w{ items people }.sort, @ctx.tables.sort
      end

      def test_tables_logs_name
        name = "hello"
        assert_logged [[name]] do
          @ctx.tables(name)
          assert_not_nil @ctx.logged.first.shift
        end
      end

      def test_columns
        columns = @ctx.columns('items').sort_by { |x| x.name }
        assert_equal 2, columns.length
        assert_equal %w{ id number }.sort, columns.map { |x| x.name }
        assert_equal [nil, nil], columns.map { |x| x.default }
        assert_equal [true, true], columns.map { |x| x.null }
      end

      def test_columns_with_default
        @ctx.execute <<-eosql
          CREATE TABLE columns_with_default (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer default 10
          )
        eosql
        column = @ctx.columns('columns_with_default').find { |x|
          x.name == 'number'
        }
        assert_equal 10, column.default
      end

      def test_columns_with_not_null
        @ctx.execute <<-eosql
          CREATE TABLE columns_with_default (
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer not null
          )
        eosql
        column = @ctx.columns('columns_with_default').find { |x|
          x.name == 'number'
        }
        assert !column.null, "column should not be null"
      end

      def test_indexes_logs
        intercept_logs_on @ctx
        assert_difference('@ctx.logged.length') do
          @ctx.indexes('items')
        end
        assert_match(/items/, @ctx.logged.last.first)
      end

      def test_no_indexes
        assert_equal [], @ctx.indexes('items')
      end

      def test_index
        @ctx.add_index 'items', 'id', :unique => true, :name => 'fun'
        index = @ctx.indexes('items').find { |idx| idx.name == 'fun' }

        assert_equal 'items', index.table
        assert index.unique, 'index is unique'
        assert_equal ['id'], index.columns
      end

      def test_non_unique_index
        @ctx.add_index 'items', 'id', :name => 'fun'
        index = @ctx.indexes('items').find { |idx| idx.name == 'fun' }
        assert !index.unique, 'index is not unique'
      end

      def test_compound_index
        @ctx.add_index 'items', %w{ id number }, :name => 'fun'
        index = @ctx.indexes('items').find { |idx| idx.name == 'fun' }
        assert_equal %w{ id number }.sort, index.columns.sort
      end

      def test_primary_key
        assert_equal 'id', @ctx.primary_key('items')

        @ctx.execute <<-eosql
          CREATE TABLE foos (
            internet integer PRIMARY KEY AUTOINCREMENT,
            number integer not null
          )
        eosql
        assert_equal 'internet', @ctx.primary_key('foos')
      end

      def test_no_primary_key
        @ctx.execute 'CREATE TABLE failboat (number integer not null)'
        assert_nil @ctx.primary_key('failboat')
      end

      private

      def assert_logged logs
        intercept_logs_on @ctx
        yield
        assert_equal logs, @ctx.logged
      end

      def intercept_logs_on ctx
        @ctx.extend(Module.new {
          attr_accessor :logged
          def log sql, name
            @logged << [sql, name]
            yield
          end
        })
        @ctx.logged = []
      end
    end
  end
end
