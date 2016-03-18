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
        id_options = decode_hash(data['identifier'])
        identifier = normalize_identifier(id_options)

        subscription_klass = connection.server.channel_classes[id_options[:channel]]

        if subscription_klass
          subscriptions[identifier] ||= subscription_klass.new(connection, identifier, id_options)
        else
          logger.error "Subscription class not found (#{data.inspect})"
        end
      end

      def remove(data)
        logger.info "Unsubscribing from channel: #{data['identifier']}"
        remove_subscription subscriptions[normalize_identifier(data['identifier'])]
      end

      def remove_subscription(subscription)
        subscription.unsubscribe_from_channel
        subscriptions.delete(subscription.identifier)
      end

      def perform_action(data)
        find(data).perform_action(decode_hash(data['data']))
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

        def normalize_identifier(identifier)
          identifier = ActiveSupport::JSON.encode(identifier) if identifier.is_a?(Hash)
          identifier
        end

        # If `data` is a Hash, this means that the original JSON
        # sent by the client had no backslashes in it, and does
        # not need to be decoded again.
        def decode_hash(data)
          data = ActiveSupport::JSON.decode(data) unless data.is_a?(Hash)
          data.with_indifferent_access
        end

        def find(data)
          if subscription = subscriptions[normalize_identifier(data['identifier'])]
            subscription
          else
            raise "Unable to find subscription with identifier: #{data['identifier']}"
          end
        end
    end
  end
end
