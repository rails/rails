# frozen_string_literal: true

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

      # Make periodic timers no-op
      def start_periodic_timers; end
      alias stop_periodic_timers start_periodic_timers
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
    #       assert_equal "chat_1", streams.last
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
    #     assert_equal "Hello, Rails!", transmissions.last["text"]
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
    #      A list of all messages that have been transmitted into the channel.
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
    #
    # == Testing broadcasting
    #
    # ActionCable::Channel::TestCase enhances ActionCable::TestHelper assertions (e.g.
    # +assert_broadcasts+) to handle broadcasting to models:
    #
    #
    #  # in your channel
    #  def speak(data)
    #    broadcast_to room, text: data["message"]
    #  end
    #
    #  def test_speak
    #    subscribe room_id: rooms[:chat].id
    #
    #    assert_broadcasts_on(rooms[:chat], text: "Hello, Rails!") do
    #      perform :speak, message: "Hello, Rails!"
    #    end
    #  end
    class TestCase < ActiveSupport::TestCase
      module Behavior
        extend ActiveSupport::Concern

        include ActiveSupport::Testing::ConstantLookup
        include ActionCable::TestHelper

        CHANNEL_IDENTIFIER = "test_stub"

        included do
          class_attribute :_channel_class

          attr_reader :connection, :subscription
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

        # Setup test connection with the specified identifiers:
        #
        #   class ApplicationCable < ActionCable::Connection::Base
        #     identified_by :user, :token
        #   end
        #
        #   stub_connection(user: users[:john], token: 'my-secret-token')
        def stub_connection(identifiers = {})
          @connection = ConnectionStub.new(identifiers)
        end

        # Subsribe to the channel under test. Optionally pass subscription parameters as a Hash.
        def subscribe(params = {})
          @connection ||= stub_connection
          # NOTE: Rails < 5.0.1 calls subscribe_to_channel during #initialize.
          #       We have to stub before it
          @subscription = self.class.channel_class.allocate
          @subscription.singleton_class.include(ChannelStub)
          @subscription.send(:initialize, connection, CHANNEL_IDENTIFIER, params.with_indifferent_access)
          # Call subscribe_to_channel if it's public (Rails 5.0.1+)
          @subscription.subscribe_to_channel if ActionCable.gem_version >= Gem::Version.new("5.0.1")
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
          connection.transmissions.map { |data| data["message"] }.compact
        end

        # Enhance TestHelper assertions to handle non-String
        # broadcastings
        def assert_broadcasts(stream_or_object, *args)
          super(broadcasting_for(stream_or_object), *args)
        end

        def assert_broadcast_on(stream_or_object, *args)
          super(broadcasting_for(stream_or_object), *args)
        end

        private
          def check_subscribed!
            raise "Must be subscribed!" if subscription.nil? || subscription.rejected?
          end

          def broadcasting_for(stream_or_object)
            return stream_or_object if stream_or_object.is_a?(String)

            self.class.channel_class.broadcasting_for(
              [self.class.channel_class.channel_name, stream_or_object]
            )
          end
      end

      include Behavior
    end
  end
end
