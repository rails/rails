require 'thread'

gem 'em-hiredis', '~> 0.3.0'
gem 'redis', '~> 3.0'
require 'em-hiredis'
require 'redis'

EventMachine.epoll  if EventMachine.epoll?
EventMachine.kqueue if EventMachine.kqueue?

module ActionCable
  module SubscriptionAdapter
    class Redis < Base # :nodoc:
      @@mutex = Mutex.new

      def initialize(*)
        super
        @redis_connection_for_broadcasts = @redis_connection_for_subscriptions = nil
      end

      def broadcast(channel, payload)
        redis_connection_for_broadcasts.publish(channel, payload)
      end

      def subscribe(channel, message_callback, success_callback = nil)
        redis_connection_for_subscriptions.pubsub.subscribe(channel, &message_callback).tap do |result|
          result.callback { |reply| success_callback.call } if success_callback
        end
      end

      def unsubscribe(channel, message_callback)
        redis_connection_for_subscriptions.pubsub.unsubscribe_proc(channel, message_callback)
      end

      def shutdown
        redis_connection_for_subscriptions.pubsub.close_connection
        @redis_connection_for_subscriptions = nil
      end

      private
        def redis_connection_for_subscriptions
          ensure_reactor_running
          @redis_connection_for_subscriptions || @server.mutex.synchronize do
            @redis_connection_for_subscriptions ||= EM::Hiredis.connect(@server.config.cable[:url]).tap do |redis|
              redis.on(:reconnect_failed) do
                @logger.info "[ActionCable] Redis reconnect failed."
              end
            end
          end
        end

        def redis_connection_for_broadcasts
          @redis_connection_for_broadcasts || @server.mutex.synchronize do
            @redis_connection_for_broadcasts ||= ::Redis.new(@server.config.cable)
          end
        end

        def ensure_reactor_running
          return if EventMachine.reactor_running?
          @@mutex.synchronize do
            Thread.new { EventMachine.run } unless EventMachine.reactor_running?
            Thread.pass until EventMachine.reactor_running?
          end
        end
    end
  end
end
