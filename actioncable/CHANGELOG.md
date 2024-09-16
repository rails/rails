*   Add `broadcast_to_list`, `stream_for_list` and `stop_stream_for_list` methods to ActionCable.
    `broadcast_to_list` broadcasts a message to broadcastings whom name respects a specific nomenclature.
    `stream_for_list` starts streaming the pubsub queue for a list of `model`
    `stop_stream_for_list` stops streaming the pubsub queue for a list of `model`

    ```ruby
    # app/channels/chat_channel.rb
    class ChatChannel < ApplicationCable::Channel
      def subscribed
        room_ids = [1, 2, 5, 7]
        stream_from_list room_ids
      end

      def unsubscribed
        room_ids = [1, 2, 5, 7]
        stop_stream_for_list room_ids
      end
    end
    ```

    ```ruby
    ChatChannel.broadcast_to_list("1", @comment)
    ```

    *xamey*

*   Add an `identifier` to the event payload for the ActiveSupport::Notification `transmit_subscription_confirmation.action_cable` and `transmit_subscription_rejection.action_cable`.

    *Keith Schacht*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actioncable/CHANGELOG.md) for previous changes.
