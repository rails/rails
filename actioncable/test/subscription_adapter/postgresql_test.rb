# frozen_string_literal: true

require "pg"
require "test_helper"
require_relative "common"
require_relative "channel_prefix"

class PostgresqlAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def setup
    database_config = { dbname: "activerecord_unittest" }

    begin
      @pg_connection = PG::Connection.new(database_config)
    rescue PG::ConnectionBad
      @rx_adapter = @tx_adapter = nil
      skip "Couldn't connect to PostgreSQL: #{database_config.inspect}"
    end

    super
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

    assert adapter.active?
  end

  def test_default_subscription_connection_identifier
    subscribe_as_queue("channel") { }

    identifiers = @pg_connection.exec("SELECT application_name FROM pg_stat_activity").field_values("application_name")
    assert_includes identifiers, "ActionCable-PID-#{$$}"
  end

  def test_custom_subscription_connection_identifier
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(id: "hello-world-42").with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    adapter = server.config.pubsub_adapter.new(server)

    subscribe_as_queue("channel", adapter) { }

    identifiers = @pg_connection.exec("SELECT application_name FROM pg_stat_activity").field_values("application_name")
    assert_includes identifiers, "hello-world-42"
  end
end
