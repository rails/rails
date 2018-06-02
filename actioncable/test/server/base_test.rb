# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/testing/method_call_assertions"

class BaseTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  def setup
    @server = ActionCable::Server::Base.new
    @server.config.cable = { adapter: "async" }.with_indifferent_access
  end

  class FakeConnection
    def close
    end
  end

  test "#restart closes all open connections" do
    conn = FakeConnection.new
    @server.add_connection(conn)

    assert_called(conn, :close) do
      @server.restart
    end
  end

  test "#restart shuts down worker pool" do
    assert_called(@server.worker_pool, :halt) do
      @server.restart
    end
  end

  test "#restart shuts down pub/sub adapter" do
    assert_called(@server.pubsub, :shutdown) do
      @server.restart
    end
  end
end
