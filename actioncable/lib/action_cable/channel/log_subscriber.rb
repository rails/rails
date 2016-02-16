require 'active_support/log_subscriber'

module ActionCable
  module Channel
    class LogSubscriber < ActiveSupport::LogSubscriber
      def perform_action(event)
        info do
          channel_class = event.payload[:channel_class]
          action = event.payload[:action]
          "Completed #{channel_class}##{action} in #{event.duration.round}ms"
        end
      end

      def transmit(event)
        info do
          channel_class = event.payload[:channel_class]
          data = event.payload[:data]
          via = event.payload[:via]
          "#{channel_class} transmitting #{data.inspect.truncate(300)}".tap { |m| m << " (via #{via})" if via }
        end
      end

      def transmit_subscription_confirmation(event)
        info do
          channel_class = event.payload[:channel_class]
          "#{channel_class} is transmitting the subscription confirmation"
        end
      end

      def transmit_subscription_rejection(event)
        info do
          channel_class = event.payload[:channel_class]
          "#{channel_class} is transmitting the subscription rejection"
        end
      end
    end
  end
end

ActionCable::Channel::LogSubscriber.attach_to :action_cable
