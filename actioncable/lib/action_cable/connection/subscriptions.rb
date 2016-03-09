require 'active_support/core_ext/hash/indifferent_access'

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
        data = normalize_data(data)

        case data['command']
        when 'subscribe'   then add data
        when 'unsubscribe' then remove data
        when 'message'     then perform_action data
        else
          logger.error "Received unrecognized command in #{data.inspect}"
        end
      rescue Exception => e
        logger.error "Could not execute command from #{data.inspect}) [#{e.class} - #{e.message}]: #{e.backtrace.first(5).join(" | ")}"
      end

      def add(data)
        id_key = data['identifier']
        id_options = json_to_hash(id_key)

        subscription_klass = connection.server.channel_classes[id_options[:channel]]

        if subscription_klass
          subscriptions[id_key] ||= subscription_klass.new(connection, id_key, id_options)
        else
          logger.error "Subscription class not found (#{data.inspect})"
        end
      end

      def remove(data)
        logger.info "Unsubscribing from channel: #{data['identifier']}"
        remove_subscription subscriptions[data['identifier']]
      end

      def remove_subscription(subscription)
        subscription.unsubscribe_from_channel
        subscriptions.delete(subscription.identifier)
      end

      def perform_action(data)
        find(data).perform_action data['data']
      end

      def identifiers
        subscriptions.keys
      end

      def unsubscribe_from_all
        subscriptions.each { |id, channel| remove_subscription(channel) }
      end

      protected
        attr_reader :connection, :subscriptions

      private
        delegate :logger, to: :connection

        def find(data)
          if subscription = subscriptions[data['identifier']]
            subscription
          else
            raise "Unable to find subscription with identifier: #{data['identifier']}"
          end
        end

        # If `data` is a Hash, this means that the original JSON
        # sent by the client had no backslashes in it, and does
        # not need to be decoded again.
        def normalize_data(data)
          data = json_to_hash(data)

          # Normalize the subscription's identifier
          data['identifier'] = hash_to_json(data['identifier']) if data['identifier']

          # Normalize the connection's message data
          data['data'] = json_to_hash(data['data']) if data['data']

          data
        end

        # Present the argument as a Hash
        def json_to_hash(data)
          data = ActiveSupport::JSON.decode(data).with_indifferent_access if !data.is_a?(Hash)
          data
        end

        # Present the argument as JSON
        def hash_to_json(data)
          data = ActiveSupport::JSON.encode(data) if data.is_a?(Hash)
          data
        end
    end
  end
end
