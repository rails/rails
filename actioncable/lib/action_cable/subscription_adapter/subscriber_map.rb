# frozen_string_literal: true

# :markup: markdown

require "concurrent/map"

module ActionCable
  module SubscriptionAdapter
    class SubscriberMap
      # A broadcast payload shared by all subscribers of a channel. It caches the
      # encoded cable message per channel identifier, so the payload is decoded and
      # re-encoded once per identifier rather than once per subscriber.
      #
      class Message < Struct.new(:data) # :nodoc:
        def initialize(...)
          super
          @cache = Concurrent::Map.new
        end

        def encoded_for(identifier)
          @cache.compute_if_absent(identifier) do
            ActiveSupport::JSON.encode({ identifier: identifier, message: ActiveSupport::JSON.decode(data) })
          end
        end

        # Behave like the underlying payload string for subscribers that expect one.
        def to_s = data
        alias_method :to_str, :to_s

        def ==(other) = data == other
        def <=>(other) = data <=> other
      end

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
          return if !@subscribers.key?(channel)
          return unless @subscribers[channel].delete(subscriber)

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

        message = Message.new(message)

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
