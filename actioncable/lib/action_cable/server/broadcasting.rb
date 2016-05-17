module ActionCable
  module Server
    # Broadcasting is how other parts of your application can send messages to a channel's subscribers. As explained in Channel, most of the time, these
    # broadcastings are streamed directly to the clients subscribed to the named broadcasting. Let's explain with a full-stack example:
    #
    #   class WebNotificationsChannel < ApplicationCable::Channel
    #     def subscribed
    #       stream_from "web_notifications_#{current_user.id}"
    #     end
    #   end
    #
    #   # Somewhere in your app this is called, perhaps from a NewCommentJob:
    #   ActionCable.server.broadcast \
    #     "web_notifications_1", { title: "New things!", body: "All that's fit for print" }
    #
    #   # Client-side CoffeeScript, which assumes you've already requested the right to send web notifications:
    #   App.cable.subscriptions.create "WebNotificationsChannel",
    #     received: (data) ->
    #       new Notification data['title'], body: data['body']
    module Broadcasting
      # Broadcast a hash directly to a named <tt>broadcasting</tt>. This will later be JSON encoded.
      def broadcast(broadcasting, message, coder: ActiveSupport::JSON)
        broadcaster_for(broadcasting, coder: coder).broadcast(message)
      end

      # Returns a broadcaster for a named <tt>broadcasting</tt> that can be reused. Useful when you have an object that
      # may need multiple spots to transmit to a specific broadcasting over and over.
      def broadcaster_for(broadcasting, coder: ActiveSupport::JSON)
        Broadcaster.new(self, String(broadcasting), coder: coder)
      end

      private
        class Broadcaster
          attr_reader :server, :broadcasting, :coder

          def initialize(server, broadcasting, coder:)
            @server, @broadcasting, @coder = server, broadcasting, coder
          end

          def broadcast(message)
            server.logger.info "[ActionCable] Broadcasting to #{broadcasting}: #{message.inspect}"
            encoded = coder ? coder.encode(message) : message
            server.pubsub.broadcast broadcasting, encoded
          end
        end
    end
  end
end
