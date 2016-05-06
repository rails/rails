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
        # Send acknowledge message to the internal connection monitor channel.
        # This is Action Cable's way of acknowledging that a request to create a
        # new subscription has been sent, and will be following up with a confirm_subscription
        # message shortly.
        logger.info "#{self.class.name} is transmitting the create subscription acknowledgement"

        id_key = data['identifier']

        ActiveSupport::Notifications.instrument("transmit_subscription_acknowledgement.action_cable", channel_class: self.class.name) do
          connection.transmit identifier: id_key, type: ActionCable::INTERNAL[:message_types][:acknowledge]
        end

        # Place subscription creation task into the worker pool
        @connection.send_async :create_subscription, self, data
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
        find(data).perform_action ActiveSupport::JSON.decode(data['data'])
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

        def create_subscription(data)
          id_key = data['identifier']
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

          subscription_klass = connection.server.channel_classes[id_options[:channel]]

          if subscription_klass
            subscriptions[id_key] ||= subscription_klass.new(connection, id_key, id_options)
          else
            logger.error "Subscription class not found (#{data.inspect})"
          end
        end

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
