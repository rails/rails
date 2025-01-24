# frozen_string_literal: true

# :markup: markdown

require "active_support"
require "active_support/test_case"
require "active_support/core_ext/hash/indifferent_access"
require "json"

module ActionCable
  module Channel
    class NonInferrableChannelError < ::StandardError
      def initialize(name)
        super "Unable to determine the channel to test from #{name}. " +
          "You'll need to specify it using `tests YourChannel` in your " +
          "test case definition."
      end
    end

    # # Action Cable Channel extensions for testing
    #
    # Add public aliases for +subscription_confirmation_sent?+ and
    # +subscription_rejected?+ and +stream_names+ to access the list of subscribed streams.
    module ChannelExt
      def confirmed? = subscription_confirmation_sent?

      def rejected? = subscription_rejected?

      def stream_names = streams.keys
    end

    # Superclass for Action Cable channel functional tests.
    #
    # ## Basic example
    #
    # Functional tests are written as follows:
    # 1.  First, one uses the `subscribe` method to simulate subscription creation.
    # 2.  Then, one asserts whether the current state is as expected. "State" can be
    #     anything: transmitted messages, subscribed streams, etc.
    #
    #
    # For example:
    #
    #     class ChatChannelTest < ActionCable::Channel::TestCase
    #       def test_subscribed_with_room_number
    #         # Simulate a subscription creation
    #         subscribe room_number: 1
    #
    #         # Asserts that the subscription was successfully created
    #         assert subscription.confirmed?
    #
    #         # Asserts that the channel subscribes connection to a stream
    #         assert_has_stream "chat_1"
    #
    #         # Asserts that the channel subscribes connection to a specific
    #         # stream created for a model
    #         assert_has_stream_for Room.find(1)
    #       end
    #
    #       def test_does_not_stream_with_incorrect_room_number
    #         subscribe room_number: -1
    #
    #         # Asserts that not streams was started
    #         assert_no_streams
    #       end
    #
    #       def test_does_not_subscribe_without_room_number
    #         subscribe
    #
    #         # Asserts that the subscription was rejected
    #         assert subscription.rejected?
    #       end
    #     end
    #
    # You can also perform actions:
    #     def test_perform_speak
    #       subscribe room_number: 1
    #
    #       perform :speak, message: "Hello, Rails!"
    #
    #       assert_equal "Hello, Rails!", transmissions.last["text"]
    #     end
    #
    # ## Special methods
    #
    # ActionCable::Channel::TestCase will also automatically provide the following
    # instance methods for use in the tests:
    #
    # connection
    # :   An ActionCable::Channel::ConnectionStub, representing the current HTTP
    #     connection.
    #
    # subscription
    # :   An instance of the current channel, created when you call `subscribe`.
    #
    # transmissions
    # :   A list of all messages that have been transmitted into the channel.
    #
    #
    # ## Channel is automatically inferred
    #
    # ActionCable::Channel::TestCase will automatically infer the channel under test
    # from the test class name. If the channel cannot be inferred from the test
    # class name, you can explicitly set it with `tests`.
    #
    #     class SpecialEdgeCaseChannelTest < ActionCable::Channel::TestCase
    #       tests SpecialChannel
    #     end
    #
    # ## Specifying connection identifiers
    #
    # You need to set up your connection manually to provide values for the
    # identifiers. To do this just use:
    #
    #     stub_connection(user: users(:john))
    #
    # ## Testing broadcasting
    #
    # ActionCable::Channel::TestCase enhances ActionCable::TestHelper assertions
    # (e.g. `assert_broadcasts`) to handle broadcasting to models:
    #
    #     # in your channel
    #     def speak(data)
    #       broadcast_to room, text: data["message"]
    #     end
    #
    #     def test_speak
    #       subscribe room_id: rooms(:chat).id
    #
    #       assert_broadcast_on(rooms(:chat), text: "Hello, Rails!") do
    #         perform :speak, message: "Hello, Rails!"
    #       end
    #     end
    class TestCase < ActionCable::Connection::TestCase
      module Behavior
        extend ActiveSupport::Concern

        include ActiveSupport::Testing::ConstantLookup
        include ActionCable::TestHelper

        CHANNEL_IDENTIFIER = "test_stub"

        included do
          class_attribute :_channel_class

          ActiveSupport.run_load_hooks(:action_cable_channel_test_case, self)
        end

        module ClassMethods
          def tests(channel)
            case channel
            when String, Symbol
              self._channel_class = channel.to_s.camelize.constantize
            when Module
              self._channel_class = channel
            else
              raise NonInferrableChannelError.new(channel)
            end
          end

          def channel_class
            if channel = self._channel_class
              channel
            else
              tests determine_default_channel(name)
            end
          end

          def tests_connection(connection)
            case connection
            when String, Symbol
              self._connection_class = connection.to_s.camelize.constantize
            when Module
              self._connection_class = connection
            else
              raise Connection::NonInferrableConnectionError.new(connection)
            end
          end

          def connection_class
            if connection = self._connection_class
              connection
            else
              tests_connection ActionCable.server.config.connection_class.call
            end
          end

          def determine_default_channel(name)
            channel = determine_constant_from_test_name(name) do |constant|
              Class === constant && constant < ActionCable::Channel::Base
            end
            raise NonInferrableChannelError.new(name) if channel.nil?
            channel
          end
        end

        # Use testserver (not test_server) to silence "Test is missing assertions: `test_server`" warnings
        attr_reader :subscription, :testserver

        # Set up test connection with the specified identifiers:
        #
        #     class ApplicationCable < ActionCable::Connection::Base
        #       identified_by :user, :token
        #     end
        #
        #     stub_connection(user: users[:john], token: 'my-secret-token')
        def stub_connection(server: ActionCable.server, **identifiers)
          @socket = Connection::TestSocket.new(Connection::TestSocket.build_request(ActionCable.server.config.mount_path || "/cable"))
          @testserver = Connection::TestServer.new(server)
          @connection = self.class.connection_class.new(testserver, socket).tap do |conn|
            identifiers.each do |identifier, val|
              conn.public_send("#{identifier}=", val)
            end
          end
        end

        # Subscribe to the channel under test. Optionally pass subscription parameters
        # as a Hash.
        def subscribe(params = {})
          @connection ||= stub_connection
          @subscription = self.class.channel_class.new(connection, CHANNEL_IDENTIFIER, params.with_indifferent_access)
          @subscription.singleton_class.include(ChannelExt)
          @subscription.subscribe_to_channel
          @subscription
        end

        # Unsubscribe the subscription under test.
        def unsubscribe
          check_subscribed!
          subscription.unsubscribe_from_channel
        end

        # Perform action on a channel.
        #
        # NOTE: Must be subscribed.
        def perform(action, data = {})
          check_subscribed!
          subscription.perform_action(data.stringify_keys.merge("action" => action.to_s))
        end

        # Returns messages transmitted into channel
        def transmissions
          # Return only directly sent message (via #transmit)
          socket.transmissions.filter_map { |data| data["message"] }
        end

        # Enhance TestHelper assertions to handle non-String broadcastings
        def assert_broadcasts(stream_or_object, *args)
          super(broadcasting_for(stream_or_object), *args)
        end

        def assert_broadcast_on(stream_or_object, *args)
          super(broadcasting_for(stream_or_object), *args)
        end

        # Asserts that no streams have been started.
        #
        #     def test_assert_no_started_stream
        #       subscribe
        #       assert_no_streams
        #     end
        #
        def assert_no_streams
          check_subscribed!
          assert subscription.stream_names.empty?, "No streams started was expected, but #{subscription.stream_names.count} found"
        end

        # Asserts that the specified stream has been started.
        #
        #     def test_assert_started_stream
        #       subscribe
        #       assert_has_stream 'messages'
        #     end
        #
        def assert_has_stream(stream)
          check_subscribed!
          assert subscription.stream_names.include?(stream), "Stream #{stream} has not been started"
        end

        # Asserts that the specified stream for a model has started.
        #
        #     def test_assert_started_stream_for
        #       subscribe id: 42
        #       assert_has_stream_for User.find(42)
        #     end
        #
        def assert_has_stream_for(object)
          assert_has_stream(broadcasting_for(object))
        end

        # Asserts that the specified stream has not been started.
        #
        #     def test_assert_no_started_stream
        #       subscribe
        #       assert_has_no_stream 'messages'
        #     end
        #
        def assert_has_no_stream(stream)
          check_subscribed!
          assert subscription.stream_names.exclude?(stream), "Stream #{stream} has been started"
        end

        # Asserts that the specified stream for a model has not started.
        #
        #     def test_assert_no_started_stream_for
        #       subscribe id: 41
        #       assert_has_no_stream_for User.find(42)
        #     end
        #
        def assert_has_no_stream_for(object)
          assert_has_no_stream(broadcasting_for(object))
        end

        private
          def check_subscribed!
            raise "Must be subscribed!" if subscription.nil? || subscription.rejected?
          end

          def broadcasting_for(stream_or_object)
            return stream_or_object if stream_or_object.is_a?(String)

            self.class.channel_class.broadcasting_for(stream_or_object)
          end
      end

      include Behavior
    end
  end
end
