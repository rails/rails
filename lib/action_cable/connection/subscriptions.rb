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
        when 'message'     then process_action data
        else
          logger.error "Received unrecognized command in #{data.inspect}"
        end
      rescue Exception => e
        logger.error "Could not execute command from #{data.inspect}) [#{e.class} - #{e.message}]: #{e.backtrace.first(5).join(" | ")}"
      end

      def add(data)
        id_key = data['identifier']
        id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

        subscription_klass = connection.server.channel_classes.detect do |channel_class|
          channel_class == id_options[:channel].safe_constantize
        end

        if subscription_klass
          subscriptions[id_key] ||= subscription_klass.new(connection, id_key, id_options)
        else
          logger.error "Subscription class not found (#{data.inspect})"
        end
      end

      def remove(data)
        logger.info "Unsubscribing from channel: #{data['identifier']}"
        subscriptions[data['identifier']].unsubscribe_from_channel
        subscriptions.delete(data['identifier'])
      end

      def process_action(data)
        find(data).process_action ActiveSupport::JSON.decode(data['data'])
      end


      def identifiers
        subscriptions.keys
      end

      def cleanup
        subscriptions.each { |id, channel| channel.unsubscribe_from_channel }
      end


      private
        attr_reader :connection, :subscriptions
        delegate :logger, to: :connection

        def find(data)
          if subscription = subscriptions[data['identifier']]
            subscription
          else
            raise "Unable to find subscription with identifier: #{data['identifier']}"
          end
        end
    end
  end
end
