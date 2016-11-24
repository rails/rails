require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/hash/indifferent_access"

class BaseTest < ActiveSupport::TestCase
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

    conn.expects(:close)
    @server.restart
  end

  test "#restart shuts down worker pool" do
    @server.worker_pool.expects(:halt)
    @server.restart
  end

  test "#restart shuts down pub/sub adapter" do
    @server.pubsub.expects(:shutdown)
    @server.restart
  end
end
