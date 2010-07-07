require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLiteAdapterTest < ActiveRecord::TestCase
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

      def assert_logged logs
        @ctx.extend(Module.new {
          attr_reader :logged
          def log sql, name
            @logged ||= []
            @logged << [sql, name]
            yield
          end
        })
        yield
        assert_equal logs, @ctx.logged
      end
    end
  end
end
