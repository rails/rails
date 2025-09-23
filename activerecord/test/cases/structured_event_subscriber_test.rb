# frozen_string_literal: true

require "cases/helper"
require "active_support/testing/event_reporter_assertions"
require "active_record/structured_event_subscriber"
require "models/developer"
require "models/binary"

module ActiveRecord
  class StructuredEventSubscriberTest < ActiveRecord::TestCase
    include ActiveSupport::Testing::EventReporterAssertions

    fixtures :developers

    Event = Struct.new(:duration, :payload)

    def run(*)
      with_debug_event_reporting do
        super
      end
    end

    def test_strict_loding_violation
      old_action = ActiveRecord.action_on_strict_loading_violation
      ActiveRecord.action_on_strict_loading_violation = :log
      developer = Developer.first.tap(&:strict_loading!)

      assert_event_reported("active_record.strict_loading_violation", payload: {
        owner: "Developer",
        class: "AuditLog",
        name: :audit_logs,
      }) do
        developer.audit_logs.to_a
      end
    ensure
      ActiveRecord.action_on_strict_loading_violation = old_action
    end

    def test_schema_statements_are_ignored
      subscriber = ActiveRecord::StructuredEventSubscriber.new

      assert_no_event_reported("active_record.sql") do
        subscriber.sql(Event.new(0.9, sql: "hi mom!", name: "SCHEMA"))
      end
    end

    def test_explain_statements_are_ignored
      subscriber = ActiveRecord::StructuredEventSubscriber.new

      assert_no_event_reported("active_record.sql") do
        subscriber.sql(Event.new(0.9, sql: "hi mom!", name: "EXPLAIN"))
      end
    end

    def test_basic_query_logging
      assert_event_reported("active_record.sql", payload: {
        name: "Developer Load",
        sql: /SELECT .*?FROM .?developers.?/i,
      }) do
        Developer.all.load
      end
    end

    def test_async_query
      subscriber = ActiveRecord::StructuredEventSubscriber.new

      assert_event_reported("active_record.sql", payload: {
        name: "Model Load",
        async: true,
        lock_wait: 0.01,
      }) do
        subscriber.sql(Event.new(0.9, sql: "SELECT * from models", name: "Model Load", async: true, lock_wait: 0.01))
      end
    end

    def test_exists_query_logging
      assert_event_reported("active_record.sql", payload: {
        name: "Developer Exists?",
        sql: /SELECT .*?FROM .?developers.?/i,
      }) do
        Developer.exists? 1
      end
    end

    def test_cached_queries
      assert_event_reported("active_record.sql", payload: {
        name: "Developer Load",
        sql: /SELECT .*?FROM .?developers.?/i,
        cached: true,
      }) do
        ActiveRecord::Base.cache do
          Developer.all.load
          Developer.all.load
        end
      end
    end

    if ActiveRecord::Base.lease_connection.prepared_statements
      def test_where_in_binds_logging_include_attribute_names
        assert_event_reported("active_record.sql", payload: {
          binds: [["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5]]
        }) do
          Developer.where(id: [1, 2, 3, 4, 5]).load
        end
      end

      def test_binary_data_is_not_logged
        assert_event_reported("active_record.sql", payload: {
          binds: [["data", "<16 bytes of binary data>"]]
        }) do
          Binary.create(data: "some binary data")
        end
      end

      def test_binary_data_hash
        event = assert_event_reported("active_record.sql", payload: { name: "Binary Create" }) do
          Binary.create(data: { a: 1 })
        end

        key, value = event.dig(:payload, :binds, 0)

        assert_equal("data", key)
        assert_match(/<(6|7) bytes of binary data>/, value)
      end
    end
  end
end
