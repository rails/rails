require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class AdapterTasksTest < ActiveRecord::TestCase

      def setup
        @config = ARTest.connection_config
      end

      test "retrieves a database adapter tasks object" do
        tasks = ActiveRecord::Model.database_tasks('arunit')
        if current_adapter?(:SQLiteAdapter)
          assert_equal('sqlite3', tasks.config[:adapter])
        elsif current_adapter?(:PostgreSQLAdapter)
          assert_equal('postgresql', tasks.config[:adapter])
        elsif current_adapter?(:MysqlAdapter)
          assert_equal('mysql', tasks.config[:adapter])
        elsif current_adapter?(:Mysql2Adapter)
          assert_equal('mysql2', tasks.config[:adapter])
        else
          skip "Adapter may not support retrieve_database_adapter"
        end
      end

      test "returns database encoding" do
        tasks = ActiveRecord::Model.database_tasks('arunit')
        if current_adapter?(:SQLiteAdapter)
          assert_equal('UTF-8', tasks.database_encoding)
        elsif current_adapter?(:PostgreSQLAdapter)
          assert_equal('UTF8', tasks.database_encoding)
        elsif current_adapter?(:AbstractMysqlAdapter)
          assert_equal('utf8', tasks.database_encoding)
        else
          skip "Adapter may not support database_encoding"
        end
      end

    end
  end
end
