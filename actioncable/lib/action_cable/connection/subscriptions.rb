require 'active_support/core_ext/hash/indifferent_access'

module ActionCable
  module Connection
    # Collection class for all the channel subscriptions established on a given connection. Responsible for routing incoming commands that arrive on
    # the connection to the proper channel. Should not be used directly by the user.
    class Subscriptions
      def initialize(connection)
        @connection = connection
        @subscriptions = {}
      end

      def execute_command(data)
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

        # If `id_key` is a Hash, this means that the original JSON
        # sent by the client had no backslashes in it, and does
        # not need to be decoded again.
        if id_key.is_a?(Hash)
          id_options = id_key.with_indifferent_access
        else
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access
        end

        subscription_klass = connection.server.channel_classes[id_options[:channel]]

        if subscription_klass
          subscriptions[id_options] ||= subscription_klass.new(connection, id_key, id_options)
        else
          logger.error "Subscription class not found (#{data.inspect})"
        end
      end

      def remove(data)
        logger.info "Unsubscribing from channel: #{data['identifier']}"
        remove_subscription subscriptions[decoded_identifier(data)]
      end

      def remove_subscription(subscription)
        subscription.unsubscribe_from_channel
        subscriptions.delete(subscription.identifier)
      end

      def perform_action(data)
        find(data).perform_action ActiveSupport::JSON.decode(data['data'])
      end

      def identifiers
        subscriptions.keys
      end

      def unsubscribe_from_all
        subscriptions.each { |id, channel| channel.unsubscribe_from_channel }
      end

      protected
        attr_reader :connection, :subscriptions

      private
        delegate :logger, to: :connection

        def decoded_identifier(data)
          ActiveSupport::JSON.decode(data['identifier'])
        end

        def find(data)
          if subscription = subscriptions[decoded_identifier(data)]
            subscription
          else
            raise "Unable to find subscription with identifier: #{data['identifier']}"
          end
        end
    end
  end
end
