# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module SubscriptionAdapter
    class SubscriberMap
      def initialize
        @subscribers = Hash.new { |h, k| h[k] = [] }
        @sync = Mutex.new
      end

      def add_subscriber(channel, subscriber, on_success)
        @sync.synchronize do
          new_channel = !@subscribers.key?(channel)

          @subscribers[channel] << subscriber

          if new_channel
            add_channel channel, on_success
          elsif on_success
            on_success.call
          end
        end
      end

      def remove_subscriber(channel, subscriber)
        @sync.synchronize do
          @subscribers[channel].delete(subscriber)

          if @subscribers[channel].empty?
            @subscribers.delete channel
            remove_channel channel
          end
        end
      end

      def broadcast(channel, message)
        list = @sync.synchronize do
          return if !@subscribers.key?(channel)
          @subscribers[channel].dup
        end

        list.each do |subscriber|
          invoke_callback(subscriber, message)
        end
      end

      def add_channel(channel, on_success)
        on_success.call if on_success
      end

      def remove_channel(channel)
      end

      def invoke_callback(callback, message)
        callback.call message
      end

      class Async < self
        def initialize(executor)
          @executor = executor
          super()
        end

        def add_subscriber(*)
          @executor.post { super }
        end

        def remove_subscriber(*)
          @executor.post { super }
        end

        def invoke_callback(*)
          @executor.post { super }
        end
      end
    end
  end
end
