# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3AdapterPreventAccessTest < ActiveRecord::SQLite3TestCase
      include DdlHelper

      self.use_transactional_tests = false

      def setup
        @conn = ActiveRecord::Base.lease_connection
      end

      def test_errors_when_a_query_is_called_while_preventing_access
        with_example_table "id int, data string" do
          @conn.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_access do
            assert_raises(ActiveRecord::PreventedAccessError) do
              @conn.execute("SELECT data from ex WHERE data = '138853948594'")
            end
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
