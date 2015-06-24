module ActionCable
  module Connection
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
        logger.error "Could not execute command from #{data.inspect})"
        connection.log_exception(e)
      end

      def add(data)
        id_key = data['identifier']
        id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

        subscription_klass = connection.server.registered_channels.detect do |channel_klass|
          channel_klass == id_options[:channel].safe_constantize
        end

        if subscription_klass
          subscriptions[id_key] = subscription_klass.new(connection, id_key, id_options)
        else
          logger.error "Subscription class not found (#{data.inspect})"
        end
      end

      def remove(data)
        logger.info "Unsubscribing from channel: #{data['identifier']}"
        subscriptions[data['identifier']].perform_disconnection
        subscriptions.delete(data['identifier'])
      end

      def perform_action(data)
        find(data).perform_action ActiveSupport::JSON.decode(data['data'])
      end


      def identifiers
        subscriptions.keys
      end

      def cleanup
        subscriptions.each { |id, channel| channel.perform_disconnection }
      end


      private
        attr_reader :connection, :subscriptions
        delegate :logger, to: :connection

        def find(data)
          if subscription = subscriptions[data['identifier']]
            subscription
          else
            raise "Unable to find subscription with identifier: #{identifier}"
          end
        end
    end
  end
end
