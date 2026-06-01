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
      ActiveRecord::Base.lease_connection.connect!
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

  def test_long_multibyte_identifiers
    # PostgreSQL identifiers are limited to 63 *bytes*. A multibyte name with <= 63
    # characters but > 63 bytes must still be hashed, otherwise PostgreSQL silently
    # truncates it: the adapter subscribes under the full name but dispatches by the
    # name wait_for_notify reports back (truncated), so the keys disagree.
    long = ("あ" * 30) + "X"   # 31 chars / 91 bytes -> over the 63-byte limit
    short = "あ" * 21          # 21 chars / 63 bytes == long's 63-byte truncation target

    subscribe_as_queue(long) do |long_queue|
      subscribe_as_queue(short) do |short_queue|
        @tx_adapter.broadcast(long, "long payload")

        # The long channel's own subscriber must receive the broadcast. Bounded wait
        # so the buggy String#size behavior (which truncates and drops the message)
        # fails here instead of blocking forever.
        assert_equal "long payload", long_queue.pop(timeout: WAIT_WHEN_EXPECTING_EVENT),
          "broadcast to a >63-byte multibyte channel must reach its own subscribers"

        # A different channel whose name equals long's 63-byte truncation must not
        # receive it. Under the bug, PostgreSQL truncates long down to short and the
        # broadcast is misrouted there.
        assert_nil short_queue.pop(timeout: WAIT_WHEN_NOT_EXPECTING_EVENT),
          "broadcast must not leak to a channel sharing long's 63-byte truncation"
      end
    end
  end

  def test_default_subscription_connection_identifier
    subscribe_as_queue("channel") { }

    identifiers = ActiveRecord::Base.lease_connection.exec_query("SELECT application_name FROM pg_stat_activity").rows
    assert_includes identifiers, ["ActionCable-PID-#{$$}"]
  end

  def test_custom_subscription_connection_identifier
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(id: "hello-world-42").with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    adapter = server.config.pubsub_adapter.new(server)

    subscribe_as_queue("channel", adapter) { }

    identifiers = ActiveRecord::Base.lease_connection.exec_query("SELECT application_name FROM pg_stat_activity").rows
    assert_includes identifiers, ["hello-world-42"]
  end
end
