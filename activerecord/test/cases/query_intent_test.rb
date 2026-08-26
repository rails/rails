# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  class QueryIntentTest < ActiveRecord::TestCase
    def setup
      super
      @connection = ActiveRecord::Base.connection_pool.send(:new_connection)
      @connection.connect!
    end

    def teardown
      @connection.disconnect!
      super
    end

    test "finalized intents cannot be delivered or reset" do
      connection = @connection
      intent = build_intent(connection)

      intent.execute!
      intent.cast_result

      assert_predicate intent, :finalized?
      assert_raises(ActiveRecord::ConnectionAdapters::QueryIntent::FinalizedError) do
        intent.deliver_result(nil)
      end
      assert_raises(ActiveRecord::ConnectionAdapters::QueryIntent::FinalizedError) do
        intent.deliver_failure(ActiveRecord::StatementInvalid.new("boom"))
      end
      assert_raises(ActiveRecord::ConnectionAdapters::QueryIntent::FinalizedError) do
        intent.reset_for_retry
      end
    end

    test "warning collection failures are delivered through the intent" do
      connection = @connection
      collect_warnings = ->(_result) { raise ActiveRecord::StatementInvalid, "warning collection failed" }

      connection.stub(:collect_warnings, collect_warnings) do
        intent = build_intent(connection)
        intent.execute!

        assert_predicate intent, :raw_result_available?
        error = assert_raises(ActiveRecord::StatementInvalid) do
          intent.cast_result
        end
        assert_equal "warning collection failed", error.message
      end
    end

    test "delivered warnings are handled once when the result is observed" do
      connection = @connection
      intent = build_intent(connection)
      warning = ActiveRecord::SQLWarning.new("warning")
      handled_warnings = []
      handle_warnings = ->(_intent, warnings) do
        handled_warnings.concat(warnings)
        raise warnings.first
      end

      connection.stub(:handle_warnings, handle_warnings) do
        intent.deliver_result(nil, warnings: [warning])

        assert_empty handled_warnings
        assert_same warning, assert_raises(ActiveRecord::SQLWarning) { intent.raw_result }
        assert_equal [warning], handled_warnings

        assert_same warning, assert_raises(ActiveRecord::SQLWarning) { intent.raw_result }
        assert_equal [warning], handled_warnings
      end
    end

    test "delivered warnings do not mask a query failure" do
      connection = @connection
      intent = build_intent(connection)
      warning = ActiveRecord::SQLWarning.new("warning")
      query_error = ActiveRecord::StatementInvalid.new("query failed")
      handled_warnings = []
      handle_warnings = ->(_intent, warnings) do
        handled_warnings.concat(warnings)
        raise warnings.first
      end

      connection.stub(:handle_warnings, handle_warnings) do
        intent.deliver_failure(query_error, warnings: [warning])

        assert_empty handled_warnings
        assert_same query_error, assert_raises(ActiveRecord::StatementInvalid) { intent.raw_result }
        assert_equal [warning], handled_warnings

        assert_same query_error, assert_raises(ActiveRecord::StatementInvalid) { intent.raw_result }
        assert_equal [warning], handled_warnings
      end
    end

    test "only delivered outcomes that materialize transactions dirty the transaction" do
      connection = @connection
      dirty_count = 0

      connection.stub(:dirty_current_transaction, -> { dirty_count += 1 }) do
        build_intent(connection, materialize_transactions: true).deliver_result(nil)
        assert_equal 1, dirty_count

        build_intent(connection, materialize_transactions: false).deliver_result(nil)
        assert_equal 1, dirty_count

        build_intent(connection, materialize_transactions: true)
          .deliver_failure(ActiveRecord::StatementInvalid.new("boom"))
        assert_equal 2, dirty_count

        build_intent(connection, materialize_transactions: false)
          .deliver_failure(ActiveRecord::StatementInvalid.new("boom"))
        assert_equal 2, dirty_count
      end
    end

    test "non-StandardError interruptions downgrade the connection and dirty the transaction" do
      connection = @connection
      connection.execute("SELECT 1")
      intent = build_intent(connection, materialize_transactions: true)
      interruption = Class.new(Exception)
      dirty_count = 0
      original_perform_query = connection.method(:perform_query)
      perform_query = ->(raw_connection, query_intent) do
        if query_intent.equal?(intent)
          raise interruption
        else
          original_perform_query.call(raw_connection, query_intent)
        end
      end

      events = connection.stub(:perform_query, perform_query) do
        connection.stub(:dirty_current_transaction, -> { dirty_count += 1 }) do
          capture_notifications("sql.active_record") do
            assert_raises(interruption) { intent.execute! }
          end
        end
      end

      event = events.find { _1.payload[:sql] == "SELECT 1" }
      assert_not_predicate connection, :verified?
      assert_nil connection.instance_variable_get(:@last_activity)
      assert_equal 1, dirty_count
      assert_predicate intent, :finalized?
      assert_not_nil event
      assert_instance_of interruption, event.payload[:exception_object]
    end

    test "handled failures are not retried again when observed repeatedly" do
      connection = @connection
      intent = build_intent(connection)
      retry_checks = 0
      error = ActiveRecord::StatementInvalid.new("boom")
      attempt_retry = ->(*) do
        retry_checks += 1
        false
      end

      connection.stub(:attempt_retry, attempt_retry) do
        intent.deliver_failure(error)

        assert_same error, assert_raises(ActiveRecord::StatementInvalid) { intent.raw_result }
        assert_same error, assert_raises(ActiveRecord::StatementInvalid) { intent.raw_result }
      end

      assert_equal 1, retry_checks
    end

    test "a retried query returns its result through one notification" do
      connection = @connection
      intent = build_intent(connection, allow_retry: true)
      attempts = 0
      original_perform_query = connection.method(:perform_query)
      perform_query = ->(raw_connection, retry_intent) do
        attempts += 1
        if attempts == 1
          raise ActiveRecord::LockWaitTimeout, "lock wait timeout"
        else
          original_perform_query.call(raw_connection, retry_intent)
        end
      end

      events = connection.stub(:connection_retries, 1) do
        connection.stub(:backoff, ->(_) { }) do
          connection.stub(:perform_query, perform_query) do
            capture_notifications("sql.active_record") do
              intent.execute!

              assert_not_predicate intent, :raw_result_available?
              assert_equal [[1]], intent.cast_result.rows
            end
          end
        end
      end

      query_events = events.select { _1.payload[:sql] == "SELECT 1" }
      assert_equal 2, attempts
      assert_equal 1, query_events.size
      assert_not query_events.first.payload.key?(:exception)
      assert_predicate intent, :finalized?
    end

    test "exhausted retries make the final failure available" do
      connection = @connection
      intent = build_intent(connection, allow_retry: true)
      perform_query_calls = 0
      perform_query = ->(*) do
        perform_query_calls += 1
        raise ActiveRecord::LockWaitTimeout, "lock wait timeout"
      end

      connection.stub(:connection_retries, 1) do
        connection.stub(:backoff, ->(_) { }) do
          connection.stub(:perform_query, perform_query) do
            intent.execute!

            assert_not_predicate intent, :raw_result_available?
            error = assert_raises(ActiveRecord::LockWaitTimeout) { intent.cast_result }
            assert_equal "lock wait timeout", error.message
          end
        end
      end

      assert_predicate intent, :raw_result_available?
      assert_predicate intent, :finalized?
      assert_equal 2, perform_query_calls
    end

    test "finalizing a provisional failure makes it available without retrying" do
      connection = @connection
      intent = build_intent(connection, allow_retry: true)
      intent.retry_budget = ActiveRecord::ConnectionAdapters::RetryBudget.new(
        retries: 1, deadline: nil, reconnectable: false
      )
      retry_checks = 0
      error = ActiveRecord::LockWaitTimeout.new("lock wait timeout")
      attempt_retry = ->(*) do
        retry_checks += 1
        true
      end

      connection.stub(:attempt_retry, attempt_retry) do
        intent.deliver_failure(error)
        assert_not_predicate intent, :raw_result_available?

        intent.finish_log(exception: error)

        assert_predicate intent, :raw_result_available?
        assert_predicate intent, :finalized?
        assert_same error, assert_raises(ActiveRecord::LockWaitTimeout) { intent.raw_result }
      end

      assert_equal 0, retry_checks
    end

    test "retryable failures dirty transactions only after final delivery" do
      connection = @connection
      intent = build_intent(connection, allow_retry: true, materialize_transactions: true)
      dirty_count = 0
      dirty_count_before_retry = nil
      perform_query_calls = 0
      original_perform_query = connection.method(:perform_query)
      perform_query = ->(raw_connection, retry_intent) do
        perform_query_calls += 1
        if perform_query_calls == 1
          raise ActiveRecord::LockWaitTimeout, "lock wait timeout"
        else
          dirty_count_before_retry = dirty_count
          original_perform_query.call(raw_connection, retry_intent)
        end
      end

      connection.stub(:connection_retries, 1) do
        connection.stub(:backoff, ->(_) { }) do
          connection.stub(:dirty_current_transaction, -> { dirty_count += 1 }) do
            connection.stub(:perform_query, perform_query) do
              intent.execute!

              assert_not_predicate intent, :raw_result_available?
              assert_equal 0, dirty_count

              intent.cast_result
            end
          end
        end
      end

      assert_equal 0, dirty_count_before_retry
      assert_equal 1, dirty_count
    end

    private
      def build_intent(connection, allow_retry: false, materialize_transactions: false)
        ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: connection,
          raw_sql: "SELECT 1",
          name: "SQL",
          allow_retry: allow_retry,
          materialize_transactions: materialize_transactions
        )
      end
  end
end
