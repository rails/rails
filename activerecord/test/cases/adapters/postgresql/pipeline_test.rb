# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class PostgresqlPipelineTest < ActiveRecord::PostgreSQLTestCase
    def setup
      super
      @connection = ActiveRecord::Base.lease_connection
      @connection.materialize_transactions
    end

    def teardown
      @connection.exit_pipeline_mode if @connection.pipeline_active?
      super
    end

    def test_pipeline_mode_lifecycle
      assert_not @connection.pipeline_active?, "Pipeline should not be active initially"

      @connection.enter_pipeline_mode
      assert @connection.pipeline_active?, "Pipeline should be active after entering"

      @connection.exit_pipeline_mode
      assert_not @connection.pipeline_active?, "Pipeline should not be active after exiting"
    end

    def test_queries_outside_pipeline_execute_immediately
      assert_not @connection.pipeline_active?

      result = @connection.exec_query("SELECT 1 AS n")

      assert_equal [[1]], result.rows
    end
  end
end
