# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stubs/test_socket"
require "stubs/room"

module ActionCable::StreamTests
  class Connection < ActionCable::Connection::Base
  end

  class ChatChannel < ActionCable::Channel::Base
    def subscribed
      if params[:id]
        @room = Room.new params[:id]
        stream_from "test_room_#{@room.id}", coder: pick_coder(params[:coder])
      end
    end

    def send_confirmation
      transmit_subscription_confirmation
    end

    private
      def pick_coder(coder)
        case coder
        when nil, "json"
          ActiveSupport::JSON
        when "custom"
          DummyEncoder
        when "none"
          nil
        end
      end
  end

  module DummyEncoder
    extend self
    def encode(*) '{ "foo": "encoded" }' end
    def decode(*) { foo: "decoded" } end
  end

  class SymbolChannel < ActionCable::Channel::Base
    def subscribed
      stream_from :channel
    end
  end

  class StreamTest < ActionCable::TestCase
    setup do
      @server = TestServer.new(subscription_adapter: SuccessAdapter)
      @pubsub = @server.pubsub
      @socket = TestSocket.new
    end

    attr_reader :socket, :server

    test "streaming start and stop" do
      connection = Connection.new(server, socket)
      pubsub = Minitest::Mock.new server.pubsub

      pubsub.expect(:subscribe, nil, ["test_room_1", Proc, Proc])
      pubsub.expect(:unsubscribe, nil, ["test_room_1", Proc])

      server.stub(:pubsub, pubsub) do
        channel = ChatChannel.new connection, "{id: 1}", id: 1
        channel.subscribe_to_channel

        channel.unsubscribe_from_channel
      end

      assert pubsub.verify
    end

    test "stream from non-string channel" do
      connection = Connection.new(server, socket)
      pubsub = Minitest::Mock.new server.pubsub

      pubsub.expect(:subscribe, nil, ["channel", Proc, Proc])
      pubsub.expect(:unsubscribe, nil, ["channel", Proc])

      server.stub(:pubsub, pubsub) do
        channel = SymbolChannel.new connection, ""
        channel.subscribe_to_channel

        channel.unsubscribe_from_channel
      end

      assert pubsub.verify
    end

    test "stream_for" do
      connection = Connection.new(server, socket)
      pubsub = Minitest::Mock.new server.pubsub

      pubsub.expect(:subscribe, nil, ["action_cable:stream_tests:chat:Room#1-Campfire", Proc, Proc])

      channel = ChatChannel.new connection, ""
      channel.subscribe_to_channel

      server.stub(:pubsub, pubsub) do
        channel.stream_for Room.new(1)
      end

      assert pubsub.verify
    end

    test "stream_or_reject_for" do
      connection = Connection.new(server, socket)
      pubsub = Minitest::Mock.new server.pubsub

      pubsub.expect(:subscribe, nil, ["action_cable:stream_tests:chat:Room#1-Campfire", Proc, Proc])

      channel = ChatChannel.new connection, ""
      channel.subscribe_to_channel

      server.stub(:pubsub, pubsub) do
        channel.stream_or_reject_for Room.new(1)
      end

      assert pubsub.verify
    end

    test "reject subscription when nil is passed to stream_or_reject_for" do
      connection = Connection.new(server, socket)

      channel = ChatChannel.new connection, "{id: 1}", id: 1
      def channel.subscribed
        stream_or_reject_for nil
      end

      channel.subscribe_to_channel

      rejection = { "identifier" => "{id: 1}", "type" => "reject_subscription" }
      assert_equal rejection, socket.last_transmission
    end

    test "stream_from subscription confirmation" do
      connection = Connection.new(server, socket)

      channel = ChatChannel.new connection, "{id: 1}", id: 1
      channel.subscribe_to_channel

      confirmation = { "identifier" => "{id: 1}", "type" => "confirm_subscription" }
      assert_equal confirmation, socket.last_transmission, "Did not receive subscription confirmation within 0.1s"
    end

    test "subscription confirmation should only be sent out once" do
      connection = Connection.new(server, socket)

      channel = ChatChannel.new connection, "test_channel"
      channel.send_confirmation
      channel.send_confirmation

      expected = { "identifier" => "test_channel", "type" => "confirm_subscription" }
      assert_equal expected, socket.last_transmission, "Did not receive subscription confirmation"

      assert_equal 1, socket.transmissions.size
    end

    test "stop_all_streams" do
      connection = Connection.new(server, socket)

      channel = ChatChannel.new connection, "{id: 3}"
      channel.subscribe_to_channel

      assert_equal 0, subscribers_of(connection).size

      channel.stream_from "room_one"
      channel.stream_from "room_two"

      assert_equal 2, subscribers_of(connection).size

      channel2 = ChatChannel.new connection, "{id: 3}"
      channel2.subscribe_to_channel

      channel2.stream_from "room_one"

      subscribers = subscribers_of(connection)

      assert_equal 2, subscribers.size
      assert_equal 2, subscribers["room_one"].size
      assert_equal 1, subscribers["room_two"].size

      channel.stop_all_streams

      subscribers = subscribers_of(connection)
      assert_equal 1, subscribers.size
      assert_equal 1, subscribers["room_one"].size
    end

    test "stop_stream_from" do
      connection = Connection.new(server, socket)

      channel = ChatChannel.new connection, "{id: 3}"
      channel.subscribe_to_channel

      channel.stream_from "room_one"
      channel.stream_from "room_two"

      channel2 = ChatChannel.new connection, "{id: 3}"
      channel2.subscribe_to_channel

      channel2.stream_from "room_one"

      subscribers = subscribers_of(connection)

      assert_equal 2, subscribers.size
      assert_equal 2, subscribers["room_one"].size
      assert_equal 1, subscribers["room_two"].size

      channel.stop_stream_from "room_one"

      subscribers = subscribers_of(connection)

      assert_equal 2, subscribers.size
      assert_equal 1, subscribers["room_one"].size
      assert_equal 1, subscribers["room_two"].size
    end

    test "stop_stream_for" do
      connection = Connection.new(server, socket)

      channel = ChatChannel.new connection, "{id: 3}"
      channel.subscribe_to_channel

      channel.stream_for Room.new(1)
      channel.stream_for Room.new(2)

      channel2 = ChatChannel.new connection, "{id: 3}"
      channel2.subscribe_to_channel

      channel2.stream_for Room.new(1)

      subscribers = subscribers_of(connection)

      assert_equal 2, subscribers.size

      assert_equal 2, subscribers[ChatChannel.broadcasting_for(Room.new(1))].size
      assert_equal 1, subscribers[ChatChannel.broadcasting_for(Room.new(2))].size

      channel.stop_stream_for Room.new(1)

      subscribers = subscribers_of(connection)

      assert_equal 2, subscribers.size
      assert_equal 1, subscribers[ChatChannel.broadcasting_for(Room.new(1))].size
      assert_equal 1, subscribers[ChatChannel.broadcasting_for(Room.new(2))].size
    end

    private
      def subscribers_of(_connection)
        server
          .pubsub
          .subscriber_map
      end
  end

  class UserCallbackChannel < ActionCable::Channel::Base
    def subscribed
      stream_from :channel do
        Thread.current[:ran_callback] = true
      end
    end
  end

  class MultiChatChannel < ActionCable::Channel::Base
    def subscribed
      stream_from "main_room"
      stream_from "test_all_rooms"
    end
  end

  class StreamFromTest < ActionCable::TestCase
    setup do
      @server = TestServer.new(subscription_adapter: ActionCable::SubscriptionAdapter::Async)
      @server.config.allowed_request_origins = %w( http://rubyonrails.com )
      @server.config.connection_class = -> { Connection }
    end

    attr_reader :socket, :server, :connection

    test "custom encoder" do
      run_in_eventmachine do
        open_connection
        subscribe_to identifiers: { id: 1 }

        server.broadcast "test_room_1", { foo: "bar" }, coder: DummyEncoder
        wait_for_async

        assert_equal({ "foo" => "encoded" }, socket.last_transmission.fetch("message"))
      end
    end

    test "user supplied callbacks are run through the worker pool" do
      run_in_eventmachine do
        open_connection
        receive(command: "subscribe", channel: UserCallbackChannel.name, identifiers: { id: 1 })

        server.broadcast "channel", {}
        wait_for_async

        assert_not Thread.current[:ran_callback], "User callback was not run through the worker pool"
      end
    end

    test "subscription confirmation should only be sent out once with multiple stream_from" do
      run_in_eventmachine do
        open_connection

        expected = { "identifier" => { "channel" => MultiChatChannel.name }.to_json, "type" => "confirm_subscription" }
        receive(command: "subscribe", channel: MultiChatChannel.name, identifiers: {})
        wait_for_async

        assert_equal expected, socket.last_transmission, "Did not receive subscription confirmation"
      end
    end

    private
      def subscribe_to(identifiers:)
        receive command: "subscribe", identifiers: identifiers
        wait_for_async
      end

      def open_connection
        @socket = TestSocket.new
        @connection = Connection.new(@server, @socket)
      end

      def receive(command:, identifiers:, channel: "ActionCable::StreamTests::ChatChannel")
        identifier = JSON.generate(identifiers.merge(channel: channel))
        connection.handle_incoming({ "command" => command, "identifier" => identifier })
      end
  end
end
