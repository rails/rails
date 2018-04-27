# frozen_string_literal: true

require "test_helper"
require "active_support/testing/method_call_assertions"
require "stubs/test_server"
require "stubs/user"

class ActionCable::Connection::IdentifierTest < ActionCable::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    attr_reader :websocket

    public :process_internal_message

    def connect
      self.current_user = User.new "lifo"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub
      assert_equal "User#lifo", @connection.connection_identifier
    end
  end

  test "should subscribe to internal channel on open and unsubscribe on close" do
    run_in_eventmachine do
      pubsub = mock("pubsub_adapter")
      pubsub.expects(:subscribe).with("action_cable/User#lifo", kind_of(Proc))
      pubsub.expects(:unsubscribe).with("action_cable/User#lifo", kind_of(Proc))

      server = TestServer.new
      server.stubs(:pubsub).returns(pubsub)

      open_connection server: server
      close_connection
    end
  end

  test "processing disconnect message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      assert_called(@connection.websocket, :close) do
        @connection.process_internal_message "type" => "disconnect"
      end
    end
  end

  test "processing invalid message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      assert_not_called(@connection.websocket, :close) do
        @connection.process_internal_message "type" => "unknown"
      end
    end
  end

  private
    def open_connection_with_stubbed_pubsub
      server = TestServer.new
      server.stubs(:adapter).returns(stub_everything("adapter"))

      open_connection server: server
    end

    def open_connection(server:)
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @connection = Connection.new(server, env)

      @connection.process
      @connection.send :handle_open
    end

    def close_connection
      @connection.send :handle_close
    end
end
