# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/object/json"

class ActionCable::Server::SocketTest < ActionCable::TestCase
  class Connection
    attr_reader :last_message, :socket, :connected

    def initialize(_server, socket)
      @socket = socket
    end

    def handle_open
      @connected = true
      socket.transmit type: "test"
    end

    def handle_close
      @connected = false
    end

    def handle_incoming(payload)
      @last_message = payload
    end
  end

  class RecordingConnection < Connection
    def log
      @log ||= Concurrent::Array.new
    end

    def handle_open
      super
      log << :open
    end

    def handle_incoming(payload)
      sleep 0.05
      log << payload["n"]
    end

    def handle_close
      super
      log << :close
    end

    def record(entry)
      log << entry
    end
  end

  class ChatChannel < ActionCable::Channel::Base
    def subscribed
      stream_from "chat"
    end
  end

  class LoginChannel < ActionCable::Channel::Base
    def login
      raise "Invalid credentials"
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
    @server.config.connection_class = -> { Connection }
  end

  test "making a connection with invalid headers" do
    run_in_eventmachine do
      socket = ActionCable::Server::Socket.new(@server, Rack::MockRequest.env_for("/test"))
      response = socket.process
      assert_equal 404, response[0]
    end
  end

  test "websocket connection" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      ws = socket.send(:websocket)

      assert_predicate ws, :possible?

      wait_for_async
      assert_predicate ws, :alive?
    end
  end

  test "rack response" do
    run_in_eventmachine do
      socket = open_socket
      response = socket.process

      assert_equal [ -1, {}, [] ], response
    end
  end

  test "on connection open" do
    run_in_eventmachine do
      socket = open_socket

      ws = socket.send(:websocket)
      mb = socket.send(:message_buffer)

      assert_called_with(ws, :transmit, [{ type: "test" }.to_json]) do
        assert_called(mb, :process!) do
          socket.process
          wait_for_async
        end
      end

      assert_equal [ socket.connection ], @server.connections
      assert socket.connection.connected
    end
  end

  test "on connection receive" do
    run_in_eventmachine do
      socket = open_socket
      socket.process
      wait_for_async

      socket.receive({ message: "hello" }.to_json)
      wait_for_async

      assert_equal({ "message" => "hello" }, socket.connection.last_message)
    end
  end

  test "processing a connection's commands in the order they arrive" do
    @server.config.connection_class = -> { ActionCable::Connection::Base }
    @server.pubsub.unsubscribe_latency = 0.1
    identifier = { channel: ChatChannel.name }.to_json

    run_in_eventmachine do
      socket = open_socket
      socket.process
      wait_for_async

      socket.receive({ command: "subscribe", identifier: identifier }.to_json)
      wait_for_async

      # A page navigation unsubscribes and resubscribes to the same channel.
      socket.receive({ command: "unsubscribe", identifier: identifier }.to_json)
      socket.receive({ command: "subscribe", identifier: identifier }.to_json)
      wait_for_async

      assert_equal [ identifier ], socket.connection.send(:subscriptions).identifiers
    end
  end

  test "filtering parameters when logging a message that could not be handled" do
    @server.config.filter_parameters = [:password]

    log = perform_failing_login

    assert_match(/Could not handle incoming message: .*alice@example\.com/, log)
    assert_no_match "secret", log
  end

  test "redacting a message that could not be handled when filtering it fails" do
    @server.config.filter_parameters = [:password, ->(key, value) { raise "Broken filter" if key == "command" }]

    log = perform_failing_login

    assert_match(/Could not handle incoming message: \[FILTERED\] \(\d+ bytes\) \[RuntimeError - Invalid credentials\]/, log)
    assert_no_match "secret", log
  end

  test "filtering parameters when logging a message processed after the WebSocket was closed" do
    identifier = { channel: LoginChannel.name, password: "secret" }.to_json
    data = { email: "alice@example.com", password: "secret" }.to_json

    log = log_message_after_close({ command: "message", identifier: identifier, data: data }.to_json)

    assert_match(/Ignoring message processed after the WebSocket was closed: .*LoginChannel.*alice@example\.com/, log)
    assert_no_match "secret", log
  end

  test "filtering a message whose data is not JSON" do
    log = log_message_after_close({ command: "message", identifier: { channel: LoginChannel.name }.to_json, data: "password=secret" }.to_json)

    assert_match(/LoginChannel.*#{Regexp.escape({ "data" => "[FILTERED]" }.inspect[1..-2])}/, log)
    assert_no_match "secret", log
  end

  test "redacting a message that is not a JSON object" do
    log = log_message_after_close([ "password", "secret" ].to_json)

    assert_match "Ignoring message processed after the WebSocket was closed: [FILTERED] (21 bytes)", log
    assert_no_match "secret", log
  end

  test "redacting a message that is not JSON" do
    log = log_message_after_close("password=secret")

    assert_match "Ignoring message processed after the WebSocket was closed: [FILTERED] (15 bytes)", log
    assert_no_match "secret", log
  end

  test "closing a connection after its earlier commands" do
    @server.config.connection_class = -> { RecordingConnection }

    run_in_eventmachine do
      socket = open_socket
      socket.process

      socket.receive({ n: 1 }.to_json)
      socket.receive({ n: 2 }.to_json)
      socket.on_close(nil, nil)
      wait_for_async

      assert_equal [ :open, 1, 2, :close ], socket.connection.log
    end
  end

  test "performing a connection's work in order with its commands" do
    @server.config.connection_class = -> { RecordingConnection }

    run_in_eventmachine do
      socket = open_socket
      socket.process

      socket.receive({ n: 1 }.to_json)
      socket.perform_work(socket.connection, :record, :work)
      socket.receive({ n: 2 }.to_json)
      wait_for_async

      assert_equal [ :open, 1, :work, 2 ], socket.connection.log
    end
  end

  test "on connection close" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      socket.send :handle_open
      assert socket.connection.connected

      socket.send :handle_close
      assert_not socket.connection.connected

      assert_empty @server.connections
    end
  end

  test "explicitly closing a connection" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      ws = socket.send(:websocket)

      assert_called(ws, :close) do
        socket.close
      end
    end
  end

  test "rejecting a connection causes a 404" do
    run_in_eventmachine do
      class CallMeMaybe
        def call(*)
          raise "Do not call me!"
        end
      end

      env = Rack::MockRequest.env_for(
        "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
          "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.org", "rack.hijack" => CallMeMaybe.new
      )

      socket = ActionCable::Server::Socket.new(@server, env)
      response = socket.process
      assert_equal 404, response[0]
    end
  end

  private
    def open_socket
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      ActionCable::Server::Socket.new(@server, env)
    end

    def capture_log
      log = StringIO.new
      @server.instance_variable_set(:@logger, ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(log)))
      log
    end

    def log_message_after_close(message)
      @server.config.filter_parameters = [:password]
      log = capture_log

      run_in_eventmachine do
        open_socket.dispatch_websocket_message(message)
      end

      log.string
    end

    def perform_failing_login
      log = capture_log
      @server.config.connection_class = -> { ActionCable::Connection::Base }
      identifier = { channel: LoginChannel.name }.to_json
      data = { action: "login", email: "alice@example.com", password: "secret" }.to_json

      run_in_eventmachine do
        socket = open_socket
        socket.process
        wait_for_async

        socket.receive({ command: "subscribe", identifier: identifier }.to_json)
        socket.receive({ command: "message", identifier: identifier, data: data }.to_json)
        wait_for_async
      end

      log.string
    end
end
