# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/hash/indifferent_access"

module ActionCable
  module Connection
    # # Action Cable Connection Subscriptions
    #
    # Collection class for all the channel subscriptions established on a given
    # connection. Responsible for routing incoming commands that arrive on the
    # connection to the proper channel.
    class Subscriptions # :nodoc:
      class Error < StandardError; end

      class AlreadySubscribedError < Error
        def initialize(identifier)
          super "Already subscribed to #{identifier}"
        end
      end

      class ChannelNotFound < Error
        def initialize(channel_id)
          super "Channel not found: #{channel_id}"
        end
      end

      class MalformedCommandError < Error
        def initialize(data)
          super "Malformed command: #{data.inspect}"
        end
      end

      class UnknownCommandError < Error
        def initialize(command)
          super "Received unrecognized command: #{command}"
        end
      end

      class UnknownSubscription < Error
        def initialize(identifier)
          super "Unable to find subscription with identifier: #{identifier}"
        end
      end

      class MissingIdentifier < Error
        def initialize
          super "Identifier is required"
        end
      end

      def initialize(connection)
        @connection = connection
        @subscriptions = {}
      end

      def execute_command(data)
        case data["command"]
        when "subscribe"   then add data
        when "unsubscribe" then remove data
        when "message"     then perform_action data
        else
          raise UnknownCommandError, data["command"]
        end
      end

      def add(data)
        id_key = data["identifier"]

        raise MalformedCommandError, data unless id_key.present?

        raise AlreadySubscribedError, id_key if subscriptions.key?(id_key)

        subscription = subscription_from_identifier(id_key)

        if subscription
          subscriptions[id_key] = subscription

          successfully_subscribed = false
          begin
            subscription.subscribe_to_channel
            successfully_subscribed = true
          ensure
            # Don't leave a half-initialized subscription occupying the
            # identifier's slot if subscribe_to_channel raised: it would reject
            # every later subscribe for that identifier with AlreadySubscribedError
            # until the connection is torn down.
            subscriptions.delete(id_key) unless successfully_subscribed
          end
        else
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
          raise ChannelNotFound, id_options[:channel]
        end
      end

      def remove(data)
        raise MissingIdentifier unless data["identifier"].present?

        logger.info "Unsubscribing from channel: #{data['identifier']}"
        subscription = find(data)
        remove_subscription(subscription) if subscription
      end

      def remove_subscription(subscription)
        subscription.unsubscribe_from_channel
        subscriptions.delete(subscription.identifier)
      end

      def perform_action(data)
        subscription = find(data)
        raise UnknownSubscription.new(data["identifier"]) unless subscription
        subscription.perform_action ActiveSupport::JSON.decode(data["data"])
      end

      def identifiers
        subscriptions.keys
      end

      def unsubscribe_from_all
        subscriptions.each { |id, channel| remove_subscription(channel) }
      end

      private
        attr_reader :connection, :subscriptions
        delegate :logger, to: :connection

        def find(data)
          subscriptions[data["identifier"]]
        end

        def subscription_from_identifier(id_key)
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
          subscription_klass = id_options[:channel]&.safe_constantize

          if subscription_klass && ActionCable::Channel::Base > subscription_klass
            subscription_klass.new(connection, id_key, id_options)
          end
        end
    end
  end
end
