require 'set'

module ActionCable
  class Server < Cramp::Websocket
    on_data :received_data
    on_finish :cleanup_subscriptions

    class_attribute :registered_channels
    self.registered_channels = Set.new

    class << self
      def register_channels(*channel_classes)
        self.registered_channels += channel_classes
      end
    end

    def initialize(*)
      @subscriptions = {}

      super
    end

    def received_data(data)
      data = ActiveSupport::JSON.decode data

      case data['action']
      when 'subscribe'
        subscribe_channel(data)
      when 'unsubscribe'
        unsubscribe_channel(data)
      when 'message'
        process_message(data)
      end
    end

    def cleanup_subscriptions
      @subscriptions.each do |id, channel|
        channel.unsubscribe
      end
    end

    def broadcast(data)
      render data
    end

    private
      def subscribe_channel(data)
        id_key = data['identifier']
        id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

        subscription_klass = registered_channels.detect do |channel_klass|
          channel_klass.find_name == id_options[:channel] && channel_klass.matches?(id_options)
        end

        if subscription_klass
          @subscriptions[id_key] = subscription_klass.new(self, id_key, id_options)
          @subscriptions[id_key].subscribe
        else
          # No channel found
        end
      end

      def process_message(message)
        id_key = message['identifier']

        if @subscriptions[id_key]
          @subscriptions[id_key].receive(ActiveSupport::JSON.decode message['data'])
        end
      end

      def unsubscribe_channel(data)
        id_key = data['identifier']
        @subscriptions[id_key].unsubscribe
        @subscriptions.delete(id_key)
      end

  end
end
