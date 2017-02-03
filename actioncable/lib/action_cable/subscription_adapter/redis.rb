require "thread"

gem "redis", "~> 3.0"
require "redis"

module ActionCable
  module SubscriptionAdapter
    class Redis < Base # :nodoc:
      prepend ChannelPrefix

      # Overwrite this factory method for redis connections if you want to use a different Redis library than Redis.
      # This is needed, for example, when using Makara proxies for distributed Redis.
      cattr_accessor(:redis_connector) { ->(config) { ::Redis.new(url: config[:url]) } }

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
          @listener || @server.mutex.synchronize { @listener ||= Listener.new(self, @server.event_loop) }
        end

        def redis_connection_for_broadcasts
          @redis_connection_for_broadcasts || @server.mutex.synchronize do
            @redis_connection_for_broadcasts ||= redis_connection
          end
        end

        def redis_connection
          self.class.redis_connector.call(@server.config.cable)
        end

        class Listener < SubscriberMap
          def initialize(adapter, event_loop)
            super()

            @adapter = adapter
            @event_loop = event_loop

            @subscribe_callbacks = Hash.new { |h, k| h[k] = [] }
            @subscription_lock = Mutex.new

            @raw_client = nil

            @when_connected = []

            @thread = nil
          end

          def listen(conn)
            conn.without_reconnect do
              original_client = conn.client

              conn.subscribe("_action_cable_internal") do |on|
                on.subscribe do |chan, count|
                  @subscription_lock.synchronize do
                    if count == 1
                      @raw_client = original_client

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
                      @raw_client = nil
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
                send_command("unsubscribe")
                @raw_client = nil
              end
            end

            Thread.pass while @thread.alive?
          end

          def add_channel(channel, on_success)
            @subscription_lock.synchronize do
              ensure_listener_running
              @subscribe_callbacks[channel] << on_success
              when_connected { send_command("subscribe", channel) }
            end
          end

          def remove_channel(channel)
            @subscription_lock.synchronize do
              when_connected { send_command("unsubscribe", channel) }
            end
          end

          def invoke_callback(*)
            @event_loop.post { super }
          end

          private
            def ensure_listener_running
              @thread ||= Thread.new do
                Thread.current.abort_on_exception = true

                conn = @adapter.redis_connection_for_subscriptions
                listen conn
              end
            end

            def when_connected(&block)
              if @raw_client
                block.call
              else
                @when_connected << block
              end
            end

            def send_command(*command)
              @raw_client.write(command)

              very_raw_connection =
                @raw_client.connection.instance_variable_defined?(:@connection) &&
                @raw_client.connection.instance_variable_get(:@connection)

              if very_raw_connection && very_raw_connection.respond_to?(:flush)
                very_raw_connection.flush
              end
            end
        end
    end
  end
end
