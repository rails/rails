require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter
      class VirtualTableTest < ActiveRecord::SQLite3TestCase

        def setup
          @connection = Base.sqlite3_connection :database => ':memory:',
                  :adapter => 'sqlite3',
                  :timeout => 100
        end

        def test_virtual_table_with_symbol
          @connection.create_table(:foo, virtual: :fts3, id: false) do |t|
            t.string :body
          end
          sql = (@connection.execute <<-SQL
            SELECT sql
            FROM sqlite_master
            WHERE name = 'foo'
          SQL
          ).first["sql"]

          assert @connection.table_exists?(:foo)
          assert_equal 'CREATE VIRTUAL TABLE "foo" USING FTS3 ("body" varchar)', sql
        end
      end
    end
  end
end
