# frozen_string_literal: true

# :markup: markdown

gem "redis", ">= 4", "< 6"
require "redis"

require "active_support/core_ext/hash/except"

module ActionCable
  module SubscriptionAdapter
    class Redis < Base # :nodoc:
      prepend ChannelPrefix

      # Overwrite this factory method for Redis connections if you want to use a
      # different Redis library than the redis gem. This is needed, for example, when
      # using Makara proxies for distributed Redis.
      cattr_accessor :redis_connector, default: ->(config) do
        ::Redis.new(config.except(:adapter, :channel_prefix))
      end

      def initialize(*)
        super
        @listener = nil
        @redis_connection_for_broadcasts = nil
      end

      def broadcast(channel, payload)
        redis_connection_for_broadcasts.publish(channel, payload)
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
          @listener || @server.mutex.synchronize { @listener ||= Listener.new(self, config_options, @server.event_loop) }
        end

        def redis_connection_for_broadcasts
          @redis_connection_for_broadcasts || @server.mutex.synchronize do
            @redis_connection_for_broadcasts ||= redis_connection
          end
        end

        def redis_connection
          self.class.redis_connector.call(config_options)
        end

        def config_options
          @config_options ||= @server.config.cable.deep_symbolize_keys.merge(id: identifier)
        end

        class Listener < SubscriberMap
          def initialize(adapter, config_options, event_loop)
            super()

            @adapter = adapter
            @event_loop = event_loop

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
            conn.without_reconnect do
              original_client = extract_subscribed_client(conn)

              conn.subscribe("_action_cable_internal") do |on|
                on.subscribe do |chan, count|
                  @subscription_lock.synchronize do
                    if count == 1
                      @reconnect_attempt = 0
                      @subscribed_client = original_client

                      until @when_connected.empty?
                        @when_connected.shift.call
                      end
                    end

                    if callbacks = @subscribe_callbacks[chan]
                      next_callback = callbacks.shift
                      @event_loop.post(&next_callback) if next_callback
                      @subscribe_callbacks.delete(chan) if callbacks.empty?
                    end
                  end
                end

                on.message do |chan, message|
                  broadcast(chan, message)
                end

                on.unsubscribe do |chan, count|
                  if count == 0
                    @subscription_lock.synchronize do
                      @subscribed_client = nil
                    end
                  end
                end
              end
            end
          end

          def shutdown
            @subscription_lock.synchronize do
              return if @thread.nil?

              when_connected do
                @subscribed_client.unsubscribe
                @subscribed_client = nil
              end
            end

            Thread.pass while @thread.alive?
          end

          def add_channel(channel, on_success)
            @subscription_lock.synchronize do
              ensure_listener_running
              @subscribe_callbacks[channel] << on_success
              when_connected { @subscribed_client.subscribe(channel) }
            end
          end

          def remove_channel(channel)
            @subscription_lock.synchronize do
              when_connected { @subscribed_client.unsubscribe(channel) }
            end
          end

          def invoke_callback(*)
            @event_loop.post { super }
          end

          private
            def ensure_listener_running
              @thread ||= Thread.new do
                Thread.current.abort_on_exception = true

                begin
                  conn = @adapter.redis_connection_for_subscriptions
                  listen conn
                rescue *CONNECTION_ERRORS
                  reset
                  if retry_connecting?
                    when_connected { resubscribe }
                    retry
                  end
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
              @subscribed_client.subscribe(*channels) unless channels.empty?
            end

            def reset
              @subscription_lock.synchronize do
                @subscribed_client = nil
                @subscribe_callbacks.clear
                @when_connected.clear
              end
            end

            if ::Redis::VERSION < "5"
              CONNECTION_ERRORS = [::Redis::BaseConnectionError].freeze

              class SubscribedClient
                def initialize(raw_client)
                  @raw_client = raw_client
                end

                def subscribe(*channel)
                  send_command("subscribe", *channel)
                end

                def unsubscribe(*channel)
                  send_command("unsubscribe", *channel)
                end

                private
                  def send_command(*command)
                    @raw_client.write(command)

                    very_raw_connection =
                      @raw_client.connection.instance_variable_defined?(:@connection) &&
                      @raw_client.connection.instance_variable_get(:@connection)

                    if very_raw_connection && very_raw_connection.respond_to?(:flush)
                      very_raw_connection.flush
                    end
                    nil
                  end
              end

              def extract_subscribed_client(conn)
                SubscribedClient.new(conn._client)
              end
            else
              CONNECTION_ERRORS = [
                ::Redis::BaseConnectionError,

                # Some older versions of redis-rb sometime leak underlying exceptions
                RedisClient::ConnectionError,
              ].freeze

              def extract_subscribed_client(conn)
                conn
              end
            end
        end
    end
  end
end
