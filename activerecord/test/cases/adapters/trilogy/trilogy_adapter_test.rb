# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"
require "models/book"
require "models/post"

require "active_support/error_reporter/test_helper"

class TrilogyAdapterTest < ActiveRecord::TrilogyTestCase
  setup do
    @configuration = {
      adapter: "trilogy",
      username: "rails",
      database: "activerecord_unittest",
    }

    @adapter = trilogy_adapter
    @adapter.execute("TRUNCATE books")
    @adapter.execute("TRUNCATE posts")

    db_config = ActiveRecord::Base.connection_pool.db_config
    pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, db_config, :writing, :default)
    @pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_config)
  end

  teardown do
    @pool.disconnect!
  end

  test "#explain for one query" do
    explain = @pool.connection.explain("select * from posts")
    assert_match %(possible_keys), explain
  end

  def trilogy_adapter_with_connection(connection, **config_overrides)
    ActiveRecord::ConnectionAdapters::TrilogyAdapter
      .new(connection, nil, {}, @configuration.merge(config_overrides))
      .tap { |conn| conn.execute("SELECT 1") }
  end

  def trilogy_adapter(**config_overrides)
    ActiveRecord::ConnectionAdapters::TrilogyAdapter
      .new(@configuration.merge(config_overrides))
  end

  def assert_raises_with_message(exception, message, &block)
    block.call
  rescue exception => error
    assert_match message, error.message
  else
    fail %(Expected #{exception} with message "#{message}" but nothing failed.)
  end

  # Create a temporary subscription to verify notification is sent.
  # Optionally verify the notification payload includes expected types.
  def assert_notification(notification, expected_payload = {}, &block)
    notification_sent = false

    subscription = lambda do |*args|
      notification_sent = true
      event = ActiveSupport::Notifications::Event.new(*args)

      expected_payload.each do |key, value|
        assert(
          value === event.payload[key],
          "Expected notification payload[:#{key}] to match #{value.inspect}, but got #{event.payload[key].inspect}."
        )
      end
    end

    ActiveSupport::Notifications.subscribed(subscription, notification) do
      block.call if block_given?
    end

    assert notification_sent, "#{notification} notification was not sent"
  end

  # Create a temporary subscription to verify notification was not sent.
  def assert_no_notification(notification, &block)
    notification_sent = false

    subscription = lambda do |*args|
      notification_sent = true
    end

    ActiveSupport::Notifications.subscribed(subscription, notification) do
      block.call if block_given?
    end

    assert_not notification_sent, "#{notification} notification was sent"
  end
end
