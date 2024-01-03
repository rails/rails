# frozen_string_literal: true

require "test_helper"
require_relative "common"
require_relative "channel_prefix"

require "active_record"

class PostgresqlAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def setup
    database_config = { "adapter" => "postgresql", "database" => "activerecord_unittest" }
    ar_tests = File.expand_path("../../../activerecord/test", __dir__)
    if Dir.exist?(ar_tests)
      require File.join(ar_tests, "config")
      require File.join(ar_tests, "support/config")
      local_config = ARTest.config["connections"]["postgresql"]["arunit"]
      database_config.update local_config if local_config
    end

    ActiveRecord::Base.establish_connection database_config

    begin
      ActiveRecord::Base.connection.connect!
    rescue
      @rx_adapter = @tx_adapter = nil
      skip "Couldn't connect to PostgreSQL: #{database_config.inspect}"
    end

    super
  end

  def teardown
    super

    ActiveRecord::Base.connection_handler.clear_all_connections!
  end

  def cable_config
    { adapter: "postgresql" }
  end

  def test_clear_active_record_connections_adapter_still_works
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    adapter_klass = Class.new(server.config.pubsub_adapter) do
      def active?
        !@listener.nil?
      end
    end

    adapter = adapter_klass.new(server)

    subscribe_as_queue("channel", adapter) do |queue|
      adapter.broadcast("channel", "hello world")
      assert_equal "hello world", queue.pop
    end

    ActiveRecord::Base.connection_handler.clear_reloadable_connections!

    assert_predicate adapter, :active?
  end

  def test_default_subscription_connection_identifier
    subscribe_as_queue("channel") { }

    identifiers = ActiveRecord::Base.connection.exec_query("SELECT application_name FROM pg_stat_activity").rows
    assert_includes identifiers, ["ActionCable-PID-#{$$}"]
  end

  def test_custom_subscription_connection_identifier
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(id: "hello-world-42").with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    adapter = server.config.pubsub_adapter.new(server)

    subscribe_as_queue("channel", adapter) { }

    identifiers = ActiveRecord::Base.connection.exec_query("SELECT application_name FROM pg_stat_activity").rows
    assert_includes identifiers, ["hello-world-42"]
  end

  # Postgres has a NOTIFY payload limit of 8000 bytes which requires special handling to avoid
  # "PG::InvalidParameterValue: ERROR: payload string too long" errors.
  def test_large_payload_broadcast
    large_payloads_table = "action_cable_large_payloads"
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute("
        CREATE TABLE IF NOT EXISTS #{large_payloads_table}
        (id serial primary key, payload text, created_at timestamp default CURRENT_TIMESTAMP)
      ")
      connection.execute("TRUNCATE TABLE #{large_payloads_table}")
    end

    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(large_payloads_table: large_payloads_table).with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }
    adapter = server.config.pubsub_adapter.new(server)

    large_payload = "a" * (ActionCable::SubscriptionAdapter::PostgreSQL::MAX_NOTIFY_SIZE + 1)

    subscribe_as_queue("channel", adapter) do |queue|
      adapter.broadcast("channel", large_payload)

      # The large payload is stored in the database at this point
      assert_equal 1, ActiveRecord::Base.connection.query("SELECT COUNT(*) FROM #{large_payloads_table}").first.first

      assert_equal large_payload, queue.pop
    end
  end

  # If the large payloads table doesn't exist, the adapter raises a helpful error
  # to aid developers in creating it.
  def test_large_payload_broadcast_without_large_payloads_table
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(large_payloads_table: "doesnt_exist").with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }
    adapter = server.config.pubsub_adapter.new(server)

    large_payload = "a" * (ActionCable::SubscriptionAdapter::PostgreSQL::MAX_NOTIFY_SIZE + 1)

    subscribe_as_queue("channel", adapter) do |queue|
      assert_raises(ActionCable::SubscriptionAdapter::PostgreSQL::PayloadTooLargeError) do
        adapter.broadcast("channel", large_payload)
        queue.pop
      end
    end
  end
end
