# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  module ConnectionAdapters
    class StandaloneConnectionTest < ActiveRecord::TestCase
      def setup
        super

        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        @connection = ActiveRecord::Base.public_send(db_config.adapter_method, db_config.configuration_hash)
      end

      def test_can_query
        result = @connection.select_all("SELECT 1")
        assert_equal [[1]], result.rows
      end

      def test_silently_ignore_async
        result = @connection.select_all("SELECT 1", async: true)
        assert_equal [[1]], result.rows
      end

      def test_can_throw_away
        @connection.throw_away!
        assert_not @connection.active?
      end

      def test_can_close
        @connection.close
      end
    end
  end
end
