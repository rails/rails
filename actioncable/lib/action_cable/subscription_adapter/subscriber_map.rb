# frozen_string_literal: true

# :markup: markdown
module ActionCable
  module SubscriptionAdapter
    class SubscriberMap
      include ActionCable::Helpers::ActionCableHelper

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

      attr_reader :subscribers

      def broadcast(channel, message)
        subscribers_list = fetch_subscribers(channel)
        return if subscribers_list.nil?

        subscribers_list.each do |subscriber|
          invoke_callback(subscriber, message)
        end
      end

      def broadcast_list(channel, message)
        subscribers_list = fetch_matching_subscribers(channel)
        return if subscribers_list.nil?

        subscribers_list.each do |subscriber|
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

      private
        def fetch_subscribers(channel)
          @sync.synchronize do
            return nil unless @subscribers.key?(channel)
            @subscribers[channel].dup
          end
        end

        def fetch_matching_subscribers(channel)
          matching_channels = find_matching_channels(channel, @subscribers.keys)
          return nil if matching_channels.empty?
          matching_channels.flat_map { |name| @subscribers[name].dup }
        end
    end
  end
end
