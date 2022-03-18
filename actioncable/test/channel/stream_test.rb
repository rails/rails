# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stubs/test_connection"
require "stubs/room"

module ActionCable::StreamTests
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket

    def send_async(method, *args)
      send method, *args
    end
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
    test "streaming start and stop" do
      run_in_eventmachine do
        connection = TestConnection.new
        pubsub = Minitest::Mock.new connection.pubsub

        pubsub.expect(:subscribe, nil, ["test_room_1", Proc, Proc])
        pubsub.expect(:unsubscribe, nil, ["test_room_1", Proc])

        connection.stub(:pubsub, pubsub) do
          channel = ChatChannel.new connection, "{id: 1}", id: 1
          channel.subscribe_to_channel

          wait_for_async
          channel.unsubscribe_from_channel
        end

        assert pubsub.verify
      end
    end

    test "stream from non-string channel" do
      run_in_eventmachine do
        connection = TestConnection.new
        pubsub = Minitest::Mock.new connection.pubsub

        pubsub.expect(:subscribe, nil, ["channel", Proc, Proc])
        pubsub.expect(:unsubscribe, nil, ["channel", Proc])

        connection.stub(:pubsub, pubsub) do
          channel = SymbolChannel.new connection, ""
          channel.subscribe_to_channel

          wait_for_async

          channel.unsubscribe_from_channel
        end

        assert pubsub.verify
      end
    end

    test "stream_for" do
      run_in_eventmachine do
        connection = TestConnection.new

        channel = ChatChannel.new connection, ""
        channel.subscribe_to_channel
        channel.stream_for Room.new(1)
        wait_for_async

        pubsub_call = channel.pubsub.class.class_variable_get "@@subscribe_called"

        assert_equal "action_cable:stream_tests:chat:Room#1-Campfire", pubsub_call[:channel]
        assert_instance_of Proc, pubsub_call[:callback]
        assert_instance_of Proc, pubsub_call[:success_callback]
      end
    end

    test "stream_or_reject_for" do
      run_in_eventmachine do
        connection = TestConnection.new

        channel = ChatChannel.new connection, ""
        channel.subscribe_to_channel
        channel.stream_or_reject_for Room.new(1)
        wait_for_async

        pubsub_call = channel.pubsub.class.class_variable_get "@@subscribe_called"

        assert_equal "action_cable:stream_tests:chat:Room#1-Campfire", pubsub_call[:channel]
        assert_instance_of Proc, pubsub_call[:callback]
        assert_instance_of Proc, pubsub_call[:success_callback]
      end
    end

    test "reject subscription when nil is passed to stream_or_reject_for" do
      run_in_eventmachine do
        connection = TestConnection.new
        channel = ChatChannel.new connection, "{id: 1}", id: 1
        channel.subscribe_to_channel
        channel.stream_or_reject_for nil
        assert_nil connection.last_transmission

        wait_for_async

        rejection = { "identifier" => "{id: 1}", "type" => "reject_subscription" }
        connection.transmit(rejection)
        assert_equal rejection, connection.last_transmission
      end
    end

    test "stream_from subscription confirmation" do
      run_in_eventmachine do
        connection = TestConnection.new

        channel = ChatChannel.new connection, "{id: 1}", id: 1
        channel.subscribe_to_channel

        assert_nil connection.last_transmission

        wait_for_async

        confirmation = { "identifier" => "{id: 1}", "type" => "confirm_subscription" }
        connection.transmit(confirmation)

        assert_equal confirmation, connection.last_transmission, "Did not receive subscription confirmation within 0.1s"
      end
    end

    test "subscription confirmation should only be sent out once" do
      run_in_eventmachine do
        connection = TestConnection.new

        channel = ChatChannel.new connection, "test_channel"
        channel.send_confirmation
        channel.send_confirmation

        wait_for_async

        expected = { "identifier" => "test_channel", "type" => "confirm_subscription" }
        assert_equal expected, connection.last_transmission, "Did not receive subscription confirmation"

        assert_equal 1, connection.transmissions.size
      end
    end

    test "stop_all_streams" do
      run_in_eventmachine do
        connection = TestConnection.new

        channel = ChatChannel.new connection, "{id: 3}"
        channel.subscribe_to_channel

        assert_equal 0, subscribers_of(connection).size

        channel.stream_from "room_one"
        channel.stream_from "room_two"

        wait_for_async
        assert_equal 2, subscribers_of(connection).size

        channel2 = ChatChannel.new connection, "{id: 3}"
        channel2.subscribe_to_channel

        channel2.stream_from "room_one"
        wait_for_async

        subscribers = subscribers_of(connection)

        assert_equal 2, subscribers.size
        assert_equal 2, subscribers["room_one"].size
        assert_equal 1, subscribers["room_two"].size

        channel.stop_all_streams

        subscribers = subscribers_of(connection)
        assert_equal 1, subscribers.size
        assert_equal 1, subscribers["room_one"].size
      end
    end

    test "stop_stream_from" do
      run_in_eventmachine do
        connection = TestConnection.new

        channel = ChatChannel.new connection, "{id: 3}"
        channel.subscribe_to_channel

        channel.stream_from "room_one"
        channel.stream_from "room_two"

        channel2 = ChatChannel.new connection, "{id: 3}"
        channel2.subscribe_to_channel

        channel2.stream_from "room_one"

        subscribers = subscribers_of(connection)

        wait_for_async

        assert_equal 2, subscribers.size
        assert_equal 2, subscribers["room_one"].size
        assert_equal 1, subscribers["room_two"].size

        channel.stop_stream_from "room_one"

        subscribers = subscribers_of(connection)

        assert_equal 2, subscribers.size
        assert_equal 1, subscribers["room_one"].size
        assert_equal 1, subscribers["room_two"].size
      end
    end

    test "stop_stream_for" do
      run_in_eventmachine do
        connection = TestConnection.new

        channel = ChatChannel.new connection, "{id: 3}"
        channel.subscribe_to_channel

        channel.stream_for Room.new(1)
        channel.stream_for Room.new(2)

        channel2 = ChatChannel.new connection, "{id: 3}"
        channel2.subscribe_to_channel

        channel2.stream_for Room.new(1)

        subscribers = subscribers_of(connection)

        wait_for_async

        assert_equal 2, subscribers.size

        assert_equal 2, subscribers[ChatChannel.broadcasting_for(Room.new(1))].size
        assert_equal 1, subscribers[ChatChannel.broadcasting_for(Room.new(2))].size

        channel.stop_stream_for Room.new(1)

        subscribers = subscribers_of(connection)

        assert_equal 2, subscribers.size
        assert_equal 1, subscribers[ChatChannel.broadcasting_for(Room.new(1))].size
        assert_equal 1, subscribers[ChatChannel.broadcasting_for(Room.new(2))].size
      end
    end

    private
      def subscribers_of(connection)
        connection
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
    end

    test "custom encoder" do
      run_in_eventmachine do
        connection = open_connection
        subscribe_to connection, identifiers: { id: 1 }

        assert_called(connection.websocket, :transmit) do
          @server.broadcast "test_room_1", { foo: "bar" }, coder: DummyEncoder
          wait_for_async
          wait_for_executor connection.server.worker_pool.executor
        end
      end
    end

    test "user supplied callbacks are run through the worker pool" do
      run_in_eventmachine do
        connection = open_connection
        receive(connection, command: "subscribe", channel: UserCallbackChannel.name, identifiers: { id: 1 })

        @server.broadcast "channel", {}
        wait_for_async
        assert_not Thread.current[:ran_callback], "User callback was not run through the worker pool"
      end
    end

    test "subscription confirmation should only be sent out once with multiple stream_from" do
      run_in_eventmachine do
        connection = open_connection
        expected = { "identifier" => { "channel" => MultiChatChannel.name }.to_json, "type" => "confirm_subscription" }
        assert_called_with(connection.websocket, :transmit, [expected.to_json]) do
          receive(connection, command: "subscribe", channel: MultiChatChannel.name, identifiers: {})
          wait_for_async
        end
      end
    end

    private
      def subscribe_to(connection, identifiers:)
        receive connection, command: "subscribe", identifiers: identifiers
      end

      def open_connection
        env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket", "HTTP_ORIGIN" => "http://rubyonrails.com"

        Connection.new(@server, env).tap do |connection|
          connection.process
          assert_predicate connection.websocket, :possible?

          wait_for_async
          assert_predicate connection.websocket, :alive?
        end
      end

      def receive(connection, command:, identifiers:, channel: "ActionCable::StreamTests::ChatChannel")
        identifier = JSON.generate(identifiers.merge(channel: channel))
        connection.dispatch_websocket_message JSON.generate(command: command, identifier: identifier)
        wait_for_async
      end
  end
end
