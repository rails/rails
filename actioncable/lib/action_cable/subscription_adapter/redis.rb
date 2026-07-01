# frozen_string_literal: true

# :markup: markdown

gem "redis-client"
require "redis-client"

require "active_support/core_ext/hash/except"

module ActionCable
  module SubscriptionAdapter
    class Redis < Base # :nodoc:
      prepend ChannelPrefix

      # Overwrite this factory method for Redis connections if you want to use a
      # different Redis library than the redis gem. This is needed, for example, when
      # using Makara proxies for distributed Redis.
      cattr_accessor :redis_connector, default: ->(config) do
        config = config.except(:adapter, :channel_prefix)
        config[:id] = "ActionCable-PID-#{$$}" unless config.key?(:id)

        redis_config = if config.key?(:sentinels)
          ::RedisClient.sentinel(**config)
        else
          ::RedisClient.config(**config)
        end
        redis_config.new_pool
      end

      def initialize(*)
        super
        @listener = nil
        @mutex = Mutex.new
        @redis_connection_for_broadcasts = nil
      end

      def broadcast(channel, payload)
        redis_connection_for_broadcasts.call("publish", channel, payload)
      end

      def subscribe(channel, callback, success_callback = nil)
        listener.add_subscriber(channel, callback, success_callback)
      end

      def unsubscribe(channel, callback)
        listener.remove_subscriber(channel, callback)
      end

      def shutdown
        @listener.shutdown if @listener
      end

      def redis_connection_for_subscriptions
        redis_connection
      end

      private
        def listener
          @listener || @mutex.synchronize { @listener ||= Listener.new(self, config_options, server) }
        end

        def redis_connection_for_broadcasts
          @redis_connection_for_broadcasts || @mutex.synchronize do
            @redis_connection_for_broadcasts ||= redis_connection
          end
        end

        def redis_connection
          self.class.redis_connector.call(config_options)
        end

        def config_options
          @config_options ||= config.cable.deep_symbolize_keys.merge(id: identifier)
        end

        class Listener < SubscriberMap::Async
          delegate :logger, to: :@adapter

          # A permanent internal subscription keeps the Redis subscription count
          # above zero while any user channel comes and goes, so removing the
          # last user channel doesn't end the listen loop. Only an explicit
          # shutdown (which unsubscribes from everything) drives the count to
          # zero and stops the listener.
          INTERNAL_CHANNEL = "_action_cable_internal"

          def initialize(adapter, config_options, server)
            super(server)

            @adapter = adapter

            @subscribe_callbacks = Hash.new { |h, k| h[k] = [] }
            @subscription_lock = Mutex.new

            @reconnect_attempt = 0
            # Use the same config as used by Redis conn
            @reconnect_attempts = config_options.fetch(:reconnect_attempts, 1)
            @reconnect_attempts = Array.new(@reconnect_attempts, 0) if @reconnect_attempts.is_a?(Integer)

            @subscribed_client = nil

            @when_connected = []

            @thread = nil
          end

          def listen(conn)
            pubsub_client = conn.pubsub

            @reconnect_attempt = 0
            @subscribed_client = pubsub_client

            pubsub_client.call("subscribe", INTERNAL_CHANNEL)

            until @when_connected.empty?
              @when_connected.shift.call
            end

            loop do
              type, chan, message = pubsub_client.next_event(60)
              case type
              when "subscribe", "psubscribe"
                if callbacks = @subscribe_callbacks[chan]
                  next_callback = callbacks.shift
                  @server.post(&next_callback) if next_callback
                  @subscribe_callbacks.delete(chan) if callbacks.empty?
                end
              when "message", "pmessage"
                broadcast(chan, message)
              when "unsubscribe", "punsubscribe"
                if message == 0
                  @subscription_lock.synchronize do
                    @subscribed_client = nil
                  end
                  break
                end
              end
            end
          end

          def shutdown
            @subscription_lock.synchronize do
              return if @thread.nil?

              when_connected do
                @subscribed_client.call("unsubscribe")
                @subscribed_client = nil
              end
            end

            Thread.pass while @thread.alive?
          end

          def add_channel(channel, on_success)
            @subscription_lock.synchronize do
              ensure_listener_running
              @subscribe_callbacks[channel] << on_success
              when_connected { @subscribed_client.call("subscribe", channel) }
            end
          end

          def remove_channel(channel)
            @subscription_lock.synchronize do
              when_connected { @subscribed_client.call("unsubscribe", channel) }
            end
          end

          private
            def ensure_listener_running
              # The internal sentinel subscription keeps the listener alive in
              # normal operation, but the thread can still die for other reasons
              # (e.g. exhausting the Redis reconnect attempts). Since this method
              # memoizes with `||=`, a dead thread would never be replaced and
              # every later subscribe would queue forever. Drop a dead thread so
              # the next subscribe spawns a fresh listener.
              if @thread && !@thread.alive?
                @thread = nil
                @reconnect_attempt = 0
              end

              @thread ||= @server.schedule do
                conn = @adapter.redis_connection_for_subscriptions
                listen conn
              rescue RedisClient::ConnectionError => e
                reset
                if retry_connecting?
                  logger&.warn "Redis connection failed: #{e.message}. Trying to reconnect..."
                  when_connected { resubscribe }
                  retry
                else
                  logger&.error "Failed to reconnect to Redis after #{@reconnect_attempt} attempts."
                end
              end
            end

            def when_connected(&block)
              if @subscribed_client
                block.call
              else
                @when_connected << block
              end
            end

            def retry_connecting?
              @reconnect_attempt += 1

              return false if @reconnect_attempt > @reconnect_attempts.size

              sleep_t = @reconnect_attempts[@reconnect_attempt - 1]

              sleep(sleep_t) if sleep_t > 0

              true
            end

            def resubscribe
              channels = @sync.synchronize do
                @subscribers.keys
              end
              @subscribed_client.call("subscribe", *channels) unless channels.empty?
            end

            def reset
              @subscription_lock.synchronize do
                @subscribed_client = nil
                @when_connected.clear
              end
            end
        end
    end
  end
end
