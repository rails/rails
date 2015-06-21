module ActionCable
  module Connection
    class Subscriptions
      def initialize(connection)
        @connection = connection
        @subscriptions = {}
      end

      def add(data)
        id_key = data['identifier']
        id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

        subscription_klass = connection.server.registered_channels.detect do |channel_klass|
          channel_klass.find_name == id_options[:channel]
        end

        if subscription_klass
          subscriptions[id_key] = subscription_klass.new(connection, id_key, id_options)
        else
          connection.logger.error "Subscription class not found (#{data.inspect})"
        end
      rescue Exception => e
        connection.logger.error "Could not subscribe to channel (#{data.inspect}) due to '#{e}': #{e.backtrace.join(' - ')}"
      end

      def remove(data)
        connection.logger.info "Unsubscribing from channel: #{data['identifier']}"
        subscriptions[data['identifier']].perform_disconnection
        subscriptions.delete(data['identifier'])
      end

      def find(identifier)
        if subscription = subscriptions[identifier]
          subscription
        else
          raise "Unable to find subscription with identifier: #{identifier}"
        end
      end

      def identifiers
        subscriptions.keys
      end

      def cleanup
        subscriptions.each do |id, channel|
          channel.perform_disconnection
        end
      end

      private
        attr_reader :connection, :subscriptions
    end
  end
end