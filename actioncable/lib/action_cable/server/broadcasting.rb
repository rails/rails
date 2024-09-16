# frozen_string_literal: true

# :markup: markdown
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
    #
    # Broadcasting to multiple subscribers without knowing the exact names of the broadcasting channels is also possible.
    # For instance, if a client subscribes to a list of models and you want to broadcast a message to this client,
    # but you only know one of the model's details on the Rails side, you can use `broadcast_list`.
    # Let's explain this with another full-stack example:
    #
    #   In this example, we want to stream to a list of users who are currently connected to our Rails app.
    #   You must follow a naming convention by specifying the list of identifiers as the last part of the channel name, separated by colons.
    #
    #   class WebNotificationsChannel < ApplicationCable::Channel
    #     def subscribed
    #       user_ids = Users.currently_connected.map(&:id)
    #       stream_from "web_notifications:#{user_ids.join('-')}"
    #     end
    #   end
    #
    #   # Somewhere in your app, this is called (perhaps from a NewCommentJob).
    #   # If the stream key is "web_notifications:1-5-6", for example, we can broadcast the message to this channel.
    #   # The last part of the name contains the user IDs, separated by hyphens.
    #   ActionCable.server.broadcast_list \
    #     "web_notifications:1", { title: "New things!", body: "All that's fit for print" }
    #
    #   # Client-side CoffeeScript:
    #   App.cable.subscriptions.create "WebNotificationsChannel",
    #     received: (data) ->
    #       new Notification data['title'], body: data['body']
    module Broadcasting
      # Broadcast a hash directly to a named <tt>broadcasting</tt>. This will later be JSON encoded.
      def broadcast(broadcasting, message, coder: ActiveSupport::JSON)
        broadcaster_for(broadcasting, coder: coder).broadcast(message)
      end

      # Broadcast a hash directly to a named <tt>broadcasting</tt> which may address multiple subscribers. This will later be JSON encoded.
      def broadcast_list(broadcasting, message, coder: ActiveSupport::JSON)
        broadcaster_for_list(broadcasting, coder: coder).broadcast(message)
      end

      # Returns a broadcaster for a named <tt>broadcasting</tt> that can be reused. Useful when you have an object that
      # may need multiple spots to transmit to a specific broadcasting over and over.
      def broadcaster_for(broadcasting, coder: ActiveSupport::JSON)
        Broadcaster.new(self, String(broadcasting), coder: coder)
      end

      # Returns a broadcaster for a named <tt>broadcasting</tt> which may address multiple subscribers that can be reused. Useful when you have an object that
      # may need multiple spots to transmit to a specific broadcasting over and over.
      def broadcaster_for_list(broadcasting, coder: ActiveSupport::JSON)
        BroadcasterList.new(self, String(broadcasting), coder: coder)
      end

      private
        class BaseBroadcaster
          attr_reader :server, :broadcasting, :coder

          def initialize(server, broadcasting, coder:)
            @server = server
            @broadcasting = broadcasting
            @coder = coder
          end

          def broadcast(message)
            @server.logger.debug { "[ActionCable] Broadcasting to #{@broadcasting}: #{message.inspect.truncate(300)}" }

            payload = { broadcasting: @broadcasting, message: message, coder: @coder }
            ActiveSupport::Notifications.instrument("broadcast.action_cable", payload) do
              encoded = @coder ? @coder.encode(message) : message
              perform_broadcast(encoded)
            end
          end

          private
            def perform_broadcast(encoded)
              raise NotImplementedError, "Subclasses must implement `perform_broadcast`"
            end
        end

        class BroadcasterList < BaseBroadcaster
          private
            def perform_broadcast(encoded)
              @server.pubsub.broadcast_list @broadcasting, encoded
            end
        end

        class Broadcaster < BaseBroadcaster
          private
            def perform_broadcast(encoded)
              @server.pubsub.broadcast @broadcasting, encoded
            end
        end
    end
  end
end
