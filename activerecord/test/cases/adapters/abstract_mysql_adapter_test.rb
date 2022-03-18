# frozen_string_literal: true

require "cases/helper"

class AbstractMysqlAdapterTest < ActiveRecord::Mysql2TestCase
  if current_adapter?(:Mysql2Adapter)
    class ExampleMysqlAdapter < ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter; end

    def setup
      @conn = ExampleMysqlAdapter.new(
        ActiveRecord::ConnectionAdapters::Mysql2Adapter.new_client({}),
        ActiveRecord::Base.logger,
        nil,
        { socket: File::NULL }
      )
    end

    def test_execute_not_raising_error
      assert_nothing_raised do
        @conn.execute("SELECT 1")
      end
    end
  end
end
