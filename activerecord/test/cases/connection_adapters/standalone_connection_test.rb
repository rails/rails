# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  module ConnectionAdapters
    class StandaloneConnectionTest < ActiveRecord::TestCase
      def setup
        super

        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        @connection = db_config.new_connection
      end

      def test_can_query
        result = @connection.select_all("SELECT 1")
        assert_equal [[1]], result.rows
      end

      def test_async_fallback
        result = @connection.select_all("SELECT 1", async: true)
        assert_instance_of FutureResult::Complete, result
        assert_equal [[1]], result.result.rows
      end

      def test_can_throw_away
        @connection.throw_away!
        assert_not @connection.active?
      end

      def test_can_close
        @connection.close
        assert_not @connection.active?
      end
    end
  end
end
