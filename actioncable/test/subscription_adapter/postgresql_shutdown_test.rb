# frozen_string_literal: true

require "test_helper"

class PostgreSQLShutdownTest < ActionCable::TestCase
  # Shutting down an adapter that was never subscribed to must be a no-op. The
  # Redis adapter guards with `@listener.shutdown if @listener`; the PostgreSQL
  # adapter used to call the memoizing `listener` accessor, which autovivified a
  # Listener (spawning a background thread + database connection) just to tear it
  # down.
  def test_shutdown_does_not_autovivify_listener
    server = ActionCable::Server::Base.new
    server.config.cable = { "adapter" => "postgresql" }
    adapter = ActionCable::SubscriptionAdapter::PostgreSQL.new(server)

    # Guard so that the (buggy) autovivified listener thread cannot touch a real
    # database; the fixed code never spawns it, so this is never called.
    adapter.define_singleton_method(:with_subscriptions_connection) { |&block| }

    assert_nil adapter.instance_variable_get(:@listener)

    adapter.shutdown

    assert_nil adapter.instance_variable_get(:@listener),
      "shutdown autovivified the listener for an adapter that was never subscribed to"
  end
end
