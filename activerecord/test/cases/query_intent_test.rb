# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  class QueryIntentTest < ActiveRecord::TestCase
    test "finalized intents cannot be delivered or reset" do
      connection = Post.lease_connection
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
      connection = Post.lease_connection
      singleton_class = connection.singleton_class

      singleton_class.define_method(:collect_warnings) do |_result|
        raise ActiveRecord::StatementInvalid, "warning collection failed"
      end

      intent = build_intent(connection)
      intent.execute!

      assert_predicate intent, :raw_result_available?
      error = assert_raises(ActiveRecord::StatementInvalid) do
        intent.cast_result
      end
      assert_equal "warning collection failed", error.message
    ensure
      singleton_class.remove_method(:collect_warnings) if singleton_class&.instance_methods(false)&.include?(:collect_warnings)
    end

    test "delivered outcomes dirty materialized transactions" do
      connection = Post.lease_connection
      dirty_count = 0
      singleton_class = connection.singleton_class

      singleton_class.define_method(:dirty_current_transaction) do
        dirty_count += 1
      end

      build_intent(connection, materialize_transactions: true).deliver_result(nil)
      build_intent(connection, materialize_transactions: true).deliver_failure(ActiveRecord::StatementInvalid.new("boom"))
      build_intent(connection, materialize_transactions: false).deliver_result(nil)
      build_intent(connection, materialize_transactions: false).deliver_failure(ActiveRecord::StatementInvalid.new("boom"))

      assert_equal 2, dirty_count
    ensure
      singleton_class.remove_method(:dirty_current_transaction) if singleton_class&.instance_methods(false)&.include?(:dirty_current_transaction)
    end

    test "non-StandardError interruptions downgrade the connection and dirty the transaction" do
      connection = Post.lease_connection
      connection.execute("SELECT 1")
      intent = build_intent(connection, materialize_transactions: true)
      singleton_class = connection.singleton_class
      original_perform_query = connection.method(:perform_query)
      interruption = Class.new(Exception)
      dirty_count = 0

      singleton_class.define_method(:perform_query) do |raw_connection, query_intent|
        if query_intent.equal?(intent)
          raise interruption
        else
          original_perform_query.call(raw_connection, query_intent)
        end
      end
      singleton_class.define_method(:dirty_current_transaction) do
        dirty_count += 1
      end

      events = capture_notifications("sql.active_record") do
        assert_raises(interruption) { intent.execute! }
      end

      event = events.find { _1.payload[:sql] == "SELECT 1" }
      assert_not_predicate connection, :verified?
      assert_nil connection.instance_variable_get(:@last_activity)
      assert_equal 1, dirty_count
      assert_predicate intent, :finalized?
      assert_not_nil event
      assert_instance_of interruption, event.payload[:exception_object]
    ensure
      singleton_class&.remove_method(:perform_query) if singleton_class&.instance_methods(false)&.include?(:perform_query)
      singleton_class&.remove_method(:dirty_current_transaction) if singleton_class&.instance_methods(false)&.include?(:dirty_current_transaction)
    end

    test "handled failures are not retried again when observed repeatedly" do
      connection = Post.lease_connection
      intent = build_intent(connection)
      singleton_class = class << connection; self; end
      retry_checks = 0
      error = ActiveRecord::StatementInvalid.new("boom")

      singleton_class.define_method(:attempt_retry) do |*|
        retry_checks += 1
        false
      end

      intent.deliver_failure(error)

      assert_same error, assert_raises(ActiveRecord::StatementInvalid) { intent.raw_result }
      assert_same error, assert_raises(ActiveRecord::StatementInvalid) { intent.raw_result }
      assert_equal 1, retry_checks
    ensure
      singleton_class&.remove_method(:attempt_retry) if singleton_class&.method_defined?(:attempt_retry)
    end

    test "retry re-enters execute_intent" do
      connection = Post.lease_connection
      intent = build_intent(connection, allow_retry: true)
      singleton_class = class << connection; self; end
      execute_intent_calls = 0
      perform_query_calls = 0
      original_execute_intent = connection.method(:execute_intent)
      original_perform_query = connection.method(:perform_query)

      singleton_class.define_method(:backoff) { |_| }
      singleton_class.define_method(:execute_intent) do |retry_intent|
        execute_intent_calls += 1
        original_execute_intent.call(retry_intent)
      end
      singleton_class.define_method(:perform_query) do |raw_connection, retry_intent|
        perform_query_calls += 1
        if perform_query_calls == 1
          raise ActiveRecord::LockWaitTimeout.new("lock wait timeout")
        else
          original_perform_query.call(raw_connection, retry_intent)
        end
      end

      intent.execute!

      assert_not_predicate intent, :raw_result_available?
      assert_equal 1, execute_intent_calls

      intent.cast_result

      assert_predicate intent, :raw_result_available?
      assert_equal 2, execute_intent_calls
    ensure
      singleton_class&.remove_method(:backoff) if singleton_class&.method_defined?(:backoff)
      singleton_class&.remove_method(:execute_intent) if singleton_class&.method_defined?(:execute_intent)
      singleton_class&.remove_method(:perform_query) if singleton_class&.method_defined?(:perform_query)
    end

    test "exhausted retries make the final failure available" do
      connection = Post.lease_connection
      intent = build_intent(connection, allow_retry: true)
      singleton_class = class << connection; self; end
      perform_query_calls = 0

      singleton_class.define_method(:backoff) { |_| }
      singleton_class.define_method(:perform_query) do |*, **|
        perform_query_calls += 1
        raise ActiveRecord::LockWaitTimeout, "lock wait timeout"
      end

      intent.execute!

      assert_not_predicate intent, :raw_result_available?
      error = assert_raises(ActiveRecord::LockWaitTimeout) { intent.cast_result }
      assert_equal "lock wait timeout", error.message
      assert_predicate intent, :raw_result_available?
      assert_predicate intent, :finalized?
      assert_equal 2, perform_query_calls
    ensure
      singleton_class&.remove_method(:backoff) if singleton_class&.method_defined?(:backoff)
      singleton_class&.remove_method(:perform_query) if singleton_class&.method_defined?(:perform_query)
    end

    test "finalizing a provisional failure makes it available without retrying" do
      connection = Post.lease_connection
      intent = build_intent(connection, allow_retry: true)
      intent.retry_budget = ActiveRecord::ConnectionAdapters::RetryBudget.new(
        retries: 1, deadline: nil, reconnectable: false
      )
      singleton_class = class << connection; self; end
      retry_checks = 0
      error = ActiveRecord::LockWaitTimeout.new("lock wait timeout")

      singleton_class.define_method(:attempt_retry) do |*|
        retry_checks += 1
        true
      end

      intent.deliver_failure(error)
      assert_not_predicate intent, :raw_result_available?

      intent.finish_log(exception: error)

      assert_predicate intent, :raw_result_available?
      assert_predicate intent, :finalized?
      assert_same error, assert_raises(ActiveRecord::LockWaitTimeout) { intent.raw_result }
      assert_equal 0, retry_checks
    ensure
      singleton_class&.remove_method(:attempt_retry) if singleton_class&.method_defined?(:attempt_retry)
    end

    test "retryable failures dirty transactions only after final delivery" do
      connection = Post.lease_connection
      intent = build_intent(connection, allow_retry: true, materialize_transactions: true)
      singleton_class = class << connection; self; end
      dirty_count = 0
      dirty_count_before_retry = nil
      perform_query_calls = 0
      original_perform_query = connection.method(:perform_query)

      singleton_class.define_method(:backoff) { |_| }
      singleton_class.define_method(:dirty_current_transaction) do
        dirty_count += 1
      end
      singleton_class.define_method(:perform_query) do |raw_connection, retry_intent|
        perform_query_calls += 1
        if perform_query_calls == 1
          raise ActiveRecord::LockWaitTimeout.new("lock wait timeout")
        else
          dirty_count_before_retry = dirty_count
          original_perform_query.call(raw_connection, retry_intent)
        end
      end

      intent.execute!

      assert_not_predicate intent, :raw_result_available?
      assert_equal 0, dirty_count

      intent.cast_result

      assert_equal 0, dirty_count_before_retry
      assert_equal 1, dirty_count
    ensure
      singleton_class&.remove_method(:backoff) if singleton_class&.method_defined?(:backoff)
      singleton_class&.remove_method(:dirty_current_transaction) if singleton_class&.method_defined?(:dirty_current_transaction)
      singleton_class&.remove_method(:perform_query) if singleton_class&.method_defined?(:perform_query)
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
