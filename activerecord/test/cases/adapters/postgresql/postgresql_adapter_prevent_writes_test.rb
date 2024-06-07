# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"
require "support/connection_helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterPreventWritesTest < ActiveRecord::PostgreSQLTestCase
      include DdlHelper
      include ConnectionHelper

      def setup
        @connection = ActiveRecord::Base.lease_connection
      end

      def test_errors_when_an_insert_query_is_called_while_preventing_writes
        with_example_table do
          ActiveRecord::Base.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @connection.execute("INSERT INTO ex (data) VALUES ('138853948594')")
            end
          end
        end
      end

      def test_errors_when_an_update_query_is_called_while_preventing_writes
        with_example_table do
          @connection.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @connection.execute("UPDATE ex SET data = '9989' WHERE data = '138853948594'")
            end
          end
        end
      end

      def test_errors_when_a_delete_query_is_called_while_preventing_writes
        with_example_table do
          @connection.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_raises(ActiveRecord::ReadOnlyError) do
              @connection.execute("DELETE FROM ex where data = '138853948594'")
            end
          end
        end
      end

      def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
        with_example_table do
          @connection.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_equal 1, @connection.execute("SELECT * FROM ex WHERE data = '138853948594'").entries.count
          end
        end
      end

      def test_doesnt_error_when_a_show_query_is_called_while_preventing_writes
        ActiveRecord::Base.while_preventing_writes do
          assert_equal 1, @connection.execute("SHOW TIME ZONE").entries.count
        end
      end

      def test_doesnt_error_when_a_set_query_is_called_while_preventing_writes
        ActiveRecord::Base.while_preventing_writes do
          assert_equal [], @connection.execute("SET standard_conforming_strings = on").entries
        end
      end

      def test_doesnt_error_when_a_read_query_with_leading_chars_is_called_while_preventing_writes
        with_example_table do
          @connection.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_writes do
            assert_equal 1, @connection.execute("/*action:index*/(\n( SELECT * FROM ex WHERE data = '138853948594' ) )").entries.count
          end
        end
      end

      def test_doesnt_error_when_a_read_query_with_cursors_is_called_while_preventing_writes
        with_example_table do
          ActiveRecord::Base.while_preventing_writes do
            @connection.transaction do
              assert_equal [], @connection.execute("DECLARE cur_ex CURSOR FOR SELECT * FROM ex").entries
              assert_equal [], @connection.execute("FETCH cur_ex").entries
              assert_equal [], @connection.execute("MOVE cur_ex").entries
              assert_equal [], @connection.execute("CLOSE cur_ex").entries
            end
          end
        end
      end

      private
        def with_example_table(definition = "id serial primary key, number integer, data character varying(255)", &block)
          super(@connection, "ex", definition, &block)
        end
    end
  end
end
