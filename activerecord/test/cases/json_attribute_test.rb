require "cases/helper"
require "cases/json_shared_test_cases"

class JsonAttributeTest < ActiveRecord::TestCase
  include JSONSharedTestCases
  self.use_transactional_tests = false

  class JsonDataTypeOnText < ActiveRecord::Base
    self.table_name = "json_data_type"

    attribute :payload,  :json
    attribute :settings, :json

    store_accessor :settings, :resolution
  end

  def setup
    super
    @connection.create_table("json_data_type") do |t|
      t.text "payload"
      t.text "settings"
    end
  end

  private
    def column_type
      :text
    end

    def klass
      JsonDataTypeOnText
    end
end
