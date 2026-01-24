# frozen_string_literal: true

require "cases/helper"
require "active_support/error_reporter/test_helper"

class WarningsTest < ActiveRecord::AbstractMysqlTestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
    @original_db_warnings_action = :ignore
  end

  test "db_warnings_action :raise on warning" do
    with_db_warnings_action(:raise) do
      error = assert_raises(ActiveRecord::SQLWarning) do
        @connection.execute('SELECT 1 + "foo"')
      end

      assert_equal @connection.pool, error.connection_pool
    end
  end

  test "db_warnings_action :ignore on warning" do
    with_db_warnings_action(:ignore) do
      result = @connection.execute('SELECT 1 + "foo"')
      assert_equal [1], result.to_a.first
    end
  end

  test "db_warnings_action :log on warning" do
    with_db_warnings_action(:log) do
      mysql_warning = "[ActiveRecord::SQLWarning] Truncated incorrect DOUBLE value: 'foo' (1292)"

      assert_called_with(ActiveRecord::Base.logger, :warn, [mysql_warning]) do
        @connection.execute('SELECT 1 + "foo"')
      end
    end
  end

  test "db_warnings_action :report on warning" do
    with_db_warnings_action(:report) do
      error_reporter = ActiveSupport::ErrorReporter.new
      subscriber = ActiveSupport::ErrorReporter::TestHelper::ErrorSubscriber.new

      Rails.define_singleton_method(:error) { error_reporter }
      Rails.error.subscribe(subscriber)

      @connection.execute('SELECT 1 + "foo"')

      warning_event, * = subscriber.events.first

      assert_kind_of ActiveRecord::SQLWarning, warning_event
      assert_equal "Truncated incorrect DOUBLE value: 'foo'", warning_event.message
    end
  end

  test "db_warnings_action custom proc on warning" do
    warning_message = nil
    warning_level = nil
    warning_action = ->(warning) do
      warning_message = warning.message
      warning_level = warning.level
    end

    with_db_warnings_action(warning_action) do
      @connection.execute('SELECT 1 + "foo"')

      assert_equal "Truncated incorrect DOUBLE value: 'foo'", warning_message
      assert_equal "Warning", warning_level
    end
  end

  test "db_warnings_action allows a list of warnings to ignore" do
    with_db_warnings_action(:raise, [/Truncated incorrect DOUBLE value/]) do
      result = @connection.execute('SELECT 1 + "foo"')

      assert_equal [1], result.to_a.first
    end
  end

  test "db_warnings_action allows a list of codes to ignore" do
    with_db_warnings_action(:raise, ["1292"]) do
      result = @connection.execute('SELECT 1 + "foo"')

      assert_equal [1], result.to_a.first
    end
  end

  test "db_warnings_action ignores note level warnings" do
    with_db_warnings_action(:raise) do
      result = @connection.execute("DROP TABLE IF EXISTS non_existent_table")

      assert_equal [], result.to_a
    end
  end

  test "db_warnings_action handles when warning_count does not match returned warnings" do
    with_db_warnings_action(:raise) do
      # force warnings to 1, but SHOW WARNINGS will return [].
      @connection.raw_connection.stub(:warning_count, 1) do
        error = assert_raises(ActiveRecord::SQLWarning) do
          @connection.execute('SELECT "x"')
        end

        expected = "Query had warning_count=1 but `SHOW WARNINGS` did not return the warnings. Check MySQL logs or database configuration."
        assert_equal expected, error.message
      end
    end
  end
end
