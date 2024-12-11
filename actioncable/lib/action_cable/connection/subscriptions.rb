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
          "Unable to find subscription with identifier: #{identifier}"
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
          subscription.subscribe_to_channel
        else
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
          raise ChannelNotFound, id_options[:channel]
        end
      end

      def remove(data)
        logger.info "Unsubscribing from channel: #{data['identifier']}"
        remove_subscription find(data)
      end

      def remove_subscription(subscription)
        subscription.unsubscribe_from_channel
        subscriptions.delete(subscription.identifier)
      end

      def perform_action(data)
        find(data).perform_action ActiveSupport::JSON.decode(data["data"])
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
          if subscription = subscriptions[data["identifier"]]
            subscription
          else
            raise UnknownSubscription, data['identifier']
          end
        end

        def subscription_from_identifier(id_key)
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
          subscription_klass = id_options[:channel].safe_constantize

          if subscription_klass && ActionCable::Channel::Base > subscription_klass
            subscription_klass.new(connection, id_key, id_options)
          end
        end
    end
  end
end
