# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"

module ActionCable
  module Connection
    # Collection class for all the channel subscriptions established on a given connection. Responsible for routing incoming commands that arrive on
    # the connection to the proper channel.
    class Subscriptions # :nodoc:
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
          logger.error "Received unrecognized command in #{data.inspect}"
        end
      rescue Exception => e
        logger.error "Could not execute command from (#{data.inspect}) [#{e.class} - #{e.message}]: #{e.backtrace.first(5).join(" | ")}"
      end

      def add(data)
        id_key = data["identifier"]
        id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

        return if subscriptions.key?(id_key)

        subscription_klass = id_options[:channel].safe_constantize

        if subscription_klass && ActionCable::Channel::Base >= subscription_klass
          subscription = subscription_klass.new(connection, id_key, id_options)
          subscriptions[id_key] = subscription
          subscription.subscribe_to_channel
        else
          logger.error "Subscription class not found: #{id_options[:channel].inspect}"
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
            raise "Unable to find subscription with identifier: #{data['identifier']}"
          end
        end
    end
  end
end
