# frozen_string_literal: true

require "cases/helper"
require "cases/json_shared_test_cases"

if ActiveRecord::Base.connection.supports_json?
  class Mysql2JSONTest < ActiveRecord::Mysql2TestCase
    include JSONSharedTestCases
    self.use_transactional_tests = false

    def setup
      super
      @connection.create_table("json_data_type") do |t|
        t.json "payload"
        t.json "settings"
      end
    end

    private
      def column_type
        :json
      end
  end
end
