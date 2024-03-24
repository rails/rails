# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"
require "support/connection_helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterPreventAccessTest < ActiveRecord::PostgreSQLTestCase
      include DdlHelper
      include ConnectionHelper

      def setup
        @connection = ActiveRecord::Base.lease_connection
      end

      def test_error_when_a_query_is_called_while_preventing_access
        with_example_table do
          @connection.execute("INSERT INTO ex (data) VALUES ('138853948594')")

          ActiveRecord::Base.while_preventing_access do
            assert_raises(ActiveRecord::PreventedAccessError) do
              @connection.execute("SELECT * FROM ex WHERE data = '138853948594'")
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
