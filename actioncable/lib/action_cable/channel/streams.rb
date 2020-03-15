# frozen_string_literal: true

module ActionCable
  module Channel
    # Streams allow channels to route broadcastings to the subscriber. A broadcasting is, as discussed elsewhere, a pubsub queue where any data
    # placed into it is automatically sent to the clients that are connected at that time. It's purely an online queue, though. If you're not
    # streaming a broadcasting at the very moment it sends out an update, you will not get that update, even if you connect after it has been sent.
    #
    # Most commonly, the streamed broadcast is sent straight to the subscriber on the client-side. The channel just acts as a connector between
    # the two parties (the broadcaster and the channel subscriber). Here's an example of a channel that allows subscribers to get all new
    # comments on a given page:
    #
    #   class CommentsChannel < ApplicationCable::Channel
    #     def follow(data)
    #       stream_from "comments_for_#{data['recording_id']}"
    #     end
    #
    #     def unfollow
    #       stop_all_streams
    #     end
    #   end
    #
    # Based on the above example, the subscribers of this channel will get whatever data is put into the,
    # let's say, <tt>comments_for_45</tt> broadcasting as soon as it's put there.
    #
    # An example broadcasting for this channel looks like so:
    #
    #   ActionCable.server.broadcast "comments_for_45", author: 'DHH', content: 'Rails is just swell'
    #
    # If you have a stream that is related to a model, then the broadcasting used can be generated from the model and channel.
    # The following example would subscribe to a broadcasting like <tt>comments:Z2lkOi8vVGVzdEFwcC9Qb3N0LzE</tt>.
    #
    #   class CommentsChannel < ApplicationCable::Channel
    #     def subscribed
    #       post = Post.find(params[:id])
    #       stream_for post
    #     end
    #   end
    #
    # You can then broadcast to this channel using:
    #
    #   CommentsChannel.broadcast_to(@post, @comment)
    #
    # If you don't just want to parlay the broadcast unfiltered to the subscriber, you can also supply a callback that lets you alter what is sent out.
    # The below example shows how you can use this to provide performance introspection in the process:
    #
    #   class ChatChannel < ApplicationCable::Channel
    #     def subscribed
    #       @room = Chat::Room[params[:room_number]]
    #
    #       stream_for @room, coder: ActiveSupport::JSON do |message|
    #         if message['originated_at'].present?
    #           elapsed_time = (Time.now.to_f - message['originated_at']).round(2)
    #
    #           ActiveSupport::Notifications.instrument :performance, measurement: 'Chat.message_delay', value: elapsed_time, action: :timing
    #           logger.info "Message took #{elapsed_time}s to arrive"
    #         end
    #
    #         transmit message
    #       end
    #     end
    #   end
    #
    # You can stop streaming from all broadcasts by calling #stop_all_streams.
    module Streams
      extend ActiveSupport::Concern

      included do
        on_unsubscribe :stop_all_streams
      end

      # Start streaming from the named <tt>broadcasting</tt> pubsub queue. Optionally, you can pass a <tt>callback</tt> that'll be used
      # instead of the default of just transmitting the updates straight to the subscriber.
      # Pass <tt>coder: ActiveSupport::JSON</tt> to decode messages as JSON before passing to the callback.
      # Defaults to <tt>coder: nil</tt> which does no decoding, passes raw messages.
      def stream_from(broadcasting, callback = nil, coder: nil, &block)
        broadcasting = String(broadcasting)

        # Don't send the confirmation until pubsub#subscribe is successful
        defer_subscription_confirmation!

        # Build a stream handler by wrapping the user-provided callback with
        # a decoder or defaulting to a JSON-decoding retransmitter.
        handler = worker_pool_stream_handler(broadcasting, callback || block, coder: coder)
        streams[broadcasting] = handler

        connection.server.event_loop.post do
          pubsub.subscribe(broadcasting, handler, lambda do
            ensure_confirmation_sent
            logger.info "#{self.class.name} is streaming from #{broadcasting}"
          end)
        end
      end

      # Start streaming the pubsub queue for the <tt>model</tt> in this channel. Optionally, you can pass a
      # <tt>callback</tt> that'll be used instead of the default of just transmitting the updates straight
      # to the subscriber.
      #
      # Pass <tt>coder: ActiveSupport::JSON</tt> to decode messages as JSON before passing to the callback.
      # Defaults to <tt>coder: nil</tt> which does no decoding, passes raw messages.
      def stream_for(model, callback = nil, coder: nil, &block)
        stream_from(broadcasting_for(model), callback || block, coder: coder)
      end

      # Unsubscribes streams from the named <tt>broadcasting</tt>.
      def stop_stream_from(broadcasting)
        callback = streams.delete(broadcasting)
        if callback
          pubsub.unsubscribe(broadcasting, callback)
          logger.info "#{self.class.name} stopped streaming from #{broadcasting}"
        end
      end

      # Unsubscribes streams for the <tt>model</tt>.
      def stop_stream_for(model)
        stop_stream_from(broadcasting_for(model))
      end

      # Unsubscribes all streams associated with this channel from the pubsub queue.
      def stop_all_streams
        streams.each do |broadcasting, callback|
          pubsub.unsubscribe broadcasting, callback
          logger.info "#{self.class.name} stopped streaming from #{broadcasting}"
        end.clear
      end

      # Calls stream_for if record is present, otherwise calls reject.
      # This method is intended to be called when you're looking
      # for a record based on a parameter, if its found it will start
      # streaming. If the record is nil then it will reject the connection.
      def stream_or_reject_for(record)
        if record
          stream_for record
        else
          reject
        end
      end

      private
        delegate :pubsub, to: :connection

        def streams
          @_streams ||= {}
        end

        # Always wrap the outermost handler to invoke the user handler on the
        # worker pool rather than blocking the event loop.
        def worker_pool_stream_handler(broadcasting, user_handler, coder: nil)
          handler = stream_handler(broadcasting, user_handler, coder: coder)

          -> message do
            connection.worker_pool.async_invoke handler, :call, message, connection: connection
          end
        end

        # May be overridden to add instrumentation, logging, specialized error
        # handling, or other forms of handler decoration.
        #
        # TODO: Tests demonstrating this.
        def stream_handler(broadcasting, user_handler, coder: nil)
          if user_handler
            stream_decoder user_handler, coder: coder
          else
            default_stream_handler broadcasting, coder: coder
          end
        end

        # May be overridden to change the default stream handling behavior
        # which decodes JSON and transmits to the client.
        #
        # TODO: Tests demonstrating this.
        #
        # TODO: Room for optimization. Update transmit API to be coder-aware
        # so we can no-op when pubsub and connection are both JSON-encoded.
        # Then we can skip decode+encode if we're just proxying messages.
        def default_stream_handler(broadcasting, coder:)
          coder ||= ActiveSupport::JSON
          stream_transmitter stream_decoder(coder: coder), broadcasting: broadcasting
        end

        def stream_decoder(handler = identity_handler, coder:)
          if coder
            -> message { handler.(coder.decode(message)) }
          else
            handler
          end
        end

        def stream_transmitter(handler = identity_handler, broadcasting:)
          via = "streamed from #{broadcasting}"

          -> (message) do
            transmit handler.(message), via: via
          end
        end

        def identity_handler
          -> message { message }
        end
    end
  end
end
