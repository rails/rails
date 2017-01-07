require "cases/helper"
require "support/schema_dumping_helper"
require "cases/adapters/shared_json_test"

if ActiveRecord::Base.connection.supports_json?
  class Mysql2JSONTest < ActiveRecord::Mysql2TestCase
    include SchemaDumpingHelper
    include JSONSharedTestCases
    self.use_transactional_tests = false

    def setup
      @connection = ActiveRecord::Base.connection
      begin
        @connection.create_table("json_data_type") do |t|
          t.json "payload"
          t.json "settings"
        end
      end
    end

    def test_change_table_supports_json
      @connection.change_table("json_data_type") do |t|
        t.json "users"
      end
      JsonDataType.reset_column_information
      column = JsonDataType.columns_hash["users"]
      assert_equal :json, column.type
    end

    def test_schema_dumping
      output = dump_table_schema("json_data_type")
      assert_match(/t\.json\s+"settings"/, output)
    end

    def column_type
      :json
    end
  end
end
