module ActionCable
  module Server
    # Broadcasting is how other parts of your application can send messages to the channel subscribers. As explained in Channel, most of the time, these
    # broadcastings are streamed directly to the clients subscribed to the named broadcasting. Let's explain with a full-stack example:
    #
    #   class WebNotificationsChannel < ApplicationCable::Channel
    #      def subscribed
    #        stream_from "web_notifications_#{current_user.id}"
    #      end
    #    end
    #
    #    # Somewhere in your app this is called, perhaps from a NewCommentJob
    #    ActionCable.server.broadcast \
    #      "web_notifications_1", { title: 'New things!', body: 'All shit fit for print' }
    #
    #    # Client-side coffescript, which assumes you've already requested the right to send web notifications
    #    App.cable.subscriptions.create "WebNotificationsChannel",
    #      received: (data) ->
    #        new Notification data['title'], body: data['body']
    module Broadcasting
      # Broadcast a hash directly to a named <tt>broadcasting</tt>. It'll automatically be JSON encoded.
      def broadcast(broadcasting, message)
        broadcaster_for(broadcasting).broadcast(message)
      end

      # Returns a broadcaster for a named <tt>broadcasting</tt> that can be reused. Useful when you have a object that
      # may need multiple spots to transmit to a specific broadcasting over and over.
      def broadcaster_for(broadcasting)
        Broadcaster.new(self, broadcasting)
      end

      private
        class Broadcaster
          attr_reader :server, :broadcasting

          def initialize(server, broadcasting)
            @server, @broadcasting = server, broadcasting
          end

          def broadcast(message)
            server.logger.info "[ActionCable] Broadcasting to #{broadcasting}: #{message}"
            broadcast_storage_adapter = server.config.storage_adapter.new(server).broadcast
            broadcast_storage_adapter.publish broadcasting, ActiveSupport::JSON.encode(message)
          end
        end
    end
  end
end
