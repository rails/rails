# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3AdapterPreventWritesTest < ActiveRecord::SQLite3TestCase
      include DdlHelper

      self.use_transactional_tests = false

      def setup
        @conn = Base.sqlite3_connection database: ":memory:",
                                        adapter: "sqlite3",
                                        timeout: 100
      end

      def test_errors_when_an_insert_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          ActiveRecord::Base.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")
            end
          end
        end
      end

      def test_errors_when_an_update_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("UPDATE ex SET data = '9989' WHERE data = '138853948594'")
            end
          end
        end
      end

      def test_errors_when_a_delete_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("DELETE FROM ex where data = '138853948594'")
            end
          end
        end
      end

      def test_errors_when_a_replace_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("REPLACE INTO ex (data) VALUES ('249823948')")
            end
          end
        end
      end

      def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_equal 1, @conn.execute("SELECT data from ex WHERE data = '138853948594'").count
          end
        end
      end

      def test_doesnt_error_when_a_read_query_with_leading_chars_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_equal 1, @conn.execute("/*action:index*/  SELECT data from ex WHERE data = '138853948594'").count
          end
        end
      end

      private
        def with_example_table(definition = nil, table_name = "ex", &block)
          definition ||= <<~SQL
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          SQL
          super(@conn, table_name, definition, &block)
        end
    end

    class SQLite3AdapterPreventWritesLegacyTest < ActiveRecord::SQLite3TestCase
      include DdlHelper
      self.use_transactional_tests = false

      def setup
        @old_value = ActiveRecord::Base.legacy_connection_handling
        ActiveRecord::Base.legacy_connection_handling = true

        @conn = Base.sqlite3_connection database: ":memory:",
                                        adapter: "sqlite3",
                                        timeout: 100

        @connection_handler = ActiveRecord::Base.connection_handler
      end

      def teardown
        ActiveRecord::Base.legacy_connection_handling = @old_value
      end

      def test_errors_when_an_insert_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @connection_handler.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")
            end
          end
        end
      end

      def test_errors_when_an_update_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          @connection_handler.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("UPDATE ex SET data = '9989' WHERE data = '138853948594'")
            end
          end
        end
      end

      def test_errors_when_a_delete_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          @connection_handler.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("DELETE FROM ex where data = '138853948594'")
            end
          end
        end
      end

      def test_errors_when_a_replace_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          @connection_handler.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @conn.execute("REPLACE INTO ex (data) VALUES ('249823948')")
            end
          end
        end
      end

      def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          @connection_handler.while_preventing_writes do
            assert_equal 1, @conn.execute("SELECT data from ex WHERE data = '138853948594'").count
          end
        end
      end

      def test_doesnt_error_when_a_read_query_with_leading_chars_is_called_while_preventing_writes
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          @connection_handler.while_preventing_writes do
            assert_equal 1, @conn.execute("/*action:index*/  SELECT data from ex WHERE data = '138853948594'").count
          end
        end
      end

      private
        def with_example_table(definition = nil, table_name = "ex", &block)
          definition ||= <<~SQL
            id integer PRIMARY KEY AUTOINCREMENT,
            number integer
          SQL
          super(@conn, table_name, definition, &block)
        end
    end
  end
end
