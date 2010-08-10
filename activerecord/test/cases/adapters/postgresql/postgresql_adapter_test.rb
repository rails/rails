require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::TestCase
      def setup
        @connection = ActiveRecord::Base.connection
      end

      def test_table_alias_length
        assert_nothing_raised do
          @connection.table_alias_length
        end
      end
    end
  end
end
