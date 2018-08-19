module ActionCable
  # Provides helper methods for testing Action Cable broadcasting
  module TestHelper
    extend ActiveSupport::Concern

    included do
      def before_setup # :nodoc:
        server = ActionCable.server
        test_adapter = ActionCable::SubscriptionAdapter::Test.new(server)

        @old_pubsub_adapter = server.pubsub

        server.instance_variable_set(:@pubsub, test_adapter)
        super
      end

      def after_teardown # :nodoc:
        super
        ActionCable.server.instance_variable_set(:@pubsub, @old_pubsub_adapter)
      end

      # Asserts that the number of broadcasted messages to the channel matches the given number.
      #
      #   def test_broadcasts
      #     assert_broadcasts 'messages', 0
      #     ActionCable.server.broadcast 'messages', { text: 'hello' }
      #     assert_broadcasts 'messages', 1
      #     ActionCable.server.broadcast 'messages', { text: 'world' }
      #     assert_broadcasts 'messages', 2
      #   end
      #
      # If a block is passed, that block should cause the specified number of
      # messages to be broadcasted.
      #
      #   def test_broadcasts_again
      #     assert_broadcasts('messages', 1) do
      #       ActionCable.server.broadcast 'messages', { text: 'hello' }
      #     end
      #
      #     assert_broadcasts('messages', 2) do
      #       ActionCable.server.broadcast 'messages', { text: 'hi' }
      #       ActionCable.server.broadcast 'messages', { text: 'how are you?' }
      #     end
      #   end
      def assert_broadcasts(channel, number)
        if block_given?
          original_count = broadcasts_size(channel)
          yield
          new_count = broadcasts_size(channel)
          assert_equal number, new_count - original_count, "#{number} broadcasts to #{channel} expected, but #{new_count - original_count} were sent"
        else
          actual_count = broadcasts_size(channel)
          assert_equal number, actual_count, "#{number} broadcasts to #{channel} expected, but #{actual_count} were sent"
        end
      end

      # Asserts that no messages have been sent to the channel.
      #
      #   def test_no_broadcasts
      #     assert_no_broadcasts 'messages'
      #     ActionCable.server.broadcast 'messages', { text: 'hi' }
      #     assert_broadcasts 'messages', 1
      #   end
      #
      # If a block is passed, that block should not cause any message to be sent.
      #
      #   def test_broadcasts_again
      #     assert_no_broadcasts 'messages' do
      #       # No job messages should be sent from this block
      #     end
      #   end
      #
      # Note: This assertion is simply a shortcut for:
      #
      #   assert_broadcasts 'messages', 0, &block
      def assert_no_broadcasts(channel, &block)
        assert_broadcasts channel, 0, &block
      end

      # Asserts that the specified message has been sent to the channel.
      #
      #   def test_assert_transmited_message
      #     ActionCable.server.broadcast 'messages', text: 'hello'
      #     assert_broadcast_on('messages', text: 'hello')
      #   end
      #
      # If a block is passed, that block should cause a message with the specified data to be sent.
      #
      #   def test_assert_broadcast_on_again
      #     assert_broadcast_on('messages', text: 'hello') do
      #       ActionCable.server.broadcast 'messages', text: 'hello'
      #     end
      #   end
      def assert_broadcast_on(channel, data)
        serialized_msg = ActiveSupport::JSON.encode(data)
        new_messages = broadcasts(channel)
        if block_given?
          old_messages = new_messages
          clear_messages(channel)

          yield
          new_messages = broadcasts(channel)
          clear_messages(channel)

          # Restore all sent messages
          (old_messages + new_messages).each { |m| pubsub_adapter.broadcast(channel, m) }
        end

        assert_includes new_messages, serialized_msg, "No messages sent with #{data} to #{channel}"
      end

      def pubsub_adapter # :nodoc:
        ActionCable.server.pubsub
      end

      delegate :broadcasts, :clear_messages, to: :pubsub_adapter

      private
        def broadcasts_size(channel) # :nodoc:
          broadcasts(channel).size
        end
    end
  end
end
