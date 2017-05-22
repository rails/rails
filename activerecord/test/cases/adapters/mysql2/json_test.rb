require "cases/helper"
require "cases/json_shared_test_cases"

if ActiveRecord::Base.connection.supports_json?
  class Mysql2JSONTest < ActiveRecord::Mysql2TestCase
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

    def teardown
      @connection.drop_table :json_data_type, if_exists: true
      JsonDataType.reset_column_information
    end

    private
      def column_type
        :json
      end
  end
end
