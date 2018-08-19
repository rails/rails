require "active_support"
require "active_support/test_case"
require "active_support/core_ext/hash/indifferent_access"
require "json"

module ActionCable
  module Channel
    class NonInferrableChannelError < ::StandardError
      def initialize(name)
        super "Unable to determine the channel to test from #{name}. " +
          "You'll need to specify it using tests YourChannel in your " +
          "test case definition."
      end
    end

    # Stub `stream_from` to track streams for the channel.
    # Add public aliases for `subscription_confirmation_sent?` and
    # `subscription_rejected?`.
    module ChannelStub
      def confirmed?
        subscription_confirmation_sent?
      end

      def rejected?
        subscription_rejected?
      end

      def stream_from(broadcasting, *)
        streams << broadcasting
      end

      def stop_all_streams
        @_streams = []
      end

      def streams
        @_streams ||= []
      end
    end

    class ConnectionStub
      attr_reader :transmissions, :identifiers, :subscriptions, :logger

      def initialize(identifiers = {})
        @transmissions = []

        identifiers.each do |identifier, val|
          define_singleton_method(identifier) { val }
        end

        @subscriptions = ActionCable::Connection::Subscriptions.new(self)
        @identifiers = identifiers.keys
        @logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
      end

      def transmit(cable_message)
        transmissions << cable_message.with_indifferent_access
      end
    end

    # Superclass for Action Cable channel functional tests.
    #
    # == Basic example
    #
    # Functional tests are written as follows:
    # 1. First, one uses the +subscribe+ method to simulate subscription creation.
    # 2. Then, one asserts whether the current state is as expected. "State" can be anything:
    #    transmitted messages, subscribed streams, etc.
    #
    # For example:
    #
    #   class ChatChannelTest < ActionCable::Channel::TestCase
    #     def test_subscribed_with_room_number
    #       # Simulate a subscription creation
    #       subscribe room_number: 1
    #
    #       # Asserts that the subscription was successfully created
    #       assert subscription.confirmed?
    #
    #       # Asserts that the channel subscribes connection to a stream
    #       assert "chat_1", streams.last
    #     end
    #
    #     def test_does_not_subscribe_without_room_number
    #       subscribe
    #
    #       # Asserts that the subscription was rejected
    #       assert subscription.rejected?
    #     end
    #   end
    #
    # You can also perform actions:
    #   def test_perform_speak
    #     subscribe room_number: 1
    #
    #     perform :speak, message: "Hello, Rails!"
    #
    #     assert_equal "Hello, Rails!", transmissions.last["message"]["text"]
    #   end
    #
    # == Special methods
    #
    # ActionCable::Channel::TestCase will also automatically provide the following instance
    # methods for use in the tests:
    #
    # <b>connection</b>::
    #      An ActionCable::Channel::ConnectionStub, representing the current HTTP connection.
    # <b>subscription</b>::
    #      An instance of the current channel, created when you call `subscribe`.
    # <b>transmissions</b>::
    #      A list of all messages that have been transmitted into the connection (without encoding).
    # <b>streams</b>::
    #      A list of all created streams subscriptions (as identifiers) for the subscription.
    #
    #
    # == Channel is automatically inferred
    #
    # ActionCable::Channel::TestCase will automatically infer the channel under test
    # from the test class name. If the channel cannot be inferred from the test
    # class name, you can explicitly set it with +tests+.
    #
    #   class SpecialEdgeCaseChannelTest < ActionCable::Channel::TestCase
    #     tests SpecialChannel
    #   end
    #
    # == Specifying connection identifiers
    #
    # You need to set up your connection manually to privide values for the identifiers.
    # To do this just use:
    #
    #   stub_connection(user: users[:john])
    class TestCase < ActiveSupport::TestCase
      module Behavior
        extend ActiveSupport::Concern

        include ActiveSupport::Testing::ConstantLookup

        included do
          class_attribute :_channel_class

          attr_reader :subscription, :connection
          delegate :transmissions, to: :connection
          delegate :streams, to: :subscription

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

          def determine_default_channel(name)
            channel = determine_constant_from_test_name(name) do |constant|
              Class === constant && constant < ActionCable::Channel::Base
            end
            raise NonInferrableChannelError.new(name) if channel.nil?
            channel
          end
        end

        def stub_connection(identifiers = {})
          @connection = ConnectionStub.new(identifiers)
        end

        def subscribe(params = {})
          @subscription = self.class.channel_class.new(connection, "test_stub", params.with_indifferent_access)
          @subscription.singleton_class.include(ChannelStub)
          @subscription.subscribe_to_channel
          @subscription
        end

        def perform(action, data = {})
          subscription.perform_action(data.stringify_keys.merge("action" => action.to_s))
        end
      end

      include Behavior
    end
  end
end
