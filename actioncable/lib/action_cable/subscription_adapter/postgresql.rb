# frozen_string_literal: true

gem "pg", "~> 1.1"
require "pg"
require "thread"
require "digest/sha1"

module ActionCable
  module SubscriptionAdapter
    class PostgreSQL < Base # :nodoc:
      prepend ChannelPrefix

      def initialize(*)
        super
        @listener = nil
      end

      def broadcast(channel, payload)
        with_broadcast_connection do |pg_conn|
          pg_conn.exec("NOTIFY #{pg_conn.escape_identifier(channel_identifier(channel))}, '#{pg_conn.escape_string(payload)}'")
        end
      end

      def subscribe(channel, callback, success_callback = nil)
        listener.add_subscriber(channel_identifier(channel), callback, success_callback)
      end

      def unsubscribe(channel, callback)
        listener.remove_subscriber(channel_identifier(channel), callback)
      end

      def shutdown
        listener.shutdown
      end

      def with_subscriptions_connection(&block) # :nodoc:
        ar_conn = ActiveRecord::Base.connection_pool.checkout.tap do |conn|
          # Action Cable is taking ownership over this database connection, and
          # will perform the necessary cleanup tasks
          ActiveRecord::Base.connection_pool.remove(conn)
        end
        pg_conn = ar_conn.raw_connection

        verify!(pg_conn)
        pg_conn.exec("SET application_name = #{pg_conn.escape_identifier(identifier)}")
        yield pg_conn
      ensure
        ar_conn.disconnect!
      end

      def with_broadcast_connection(&block) # :nodoc:
        ActiveRecord::Base.connection_pool.with_connection do |ar_conn|
          pg_conn = ar_conn.raw_connection
          verify!(pg_conn)
          yield pg_conn
        end
      end

      private
        def channel_identifier(channel)
          channel.size > 63 ? Digest::SHA1.hexdigest(channel) : channel
        end

        def listener
          @listener || @server.mutex.synchronize { @listener ||= Listener.new(self, @server.event_loop) }
        end

        def verify!(pg_conn)
          unless pg_conn.is_a?(PG::Connection)
            raise "The Active Record database must be PostgreSQL in order to use the PostgreSQL Action Cable storage adapter"
          end
        end

        class Listener < SubscriberMap
          def initialize(adapter, event_loop)
            super()

            @adapter = adapter
            @event_loop = event_loop
            @queue = Queue.new

            @thread = Thread.new do
              Thread.current.abort_on_exception = true
              listen
            end
          end

          def listen
            @adapter.with_subscriptions_connection do |pg_conn|
              catch :shutdown do
                loop do
                  until @queue.empty?
                    action, channel, callback = @queue.pop(true)

                    case action
                    when :listen
                      pg_conn.exec("LISTEN #{pg_conn.escape_identifier channel}")
                      @event_loop.post(&callback) if callback
                    when :unlisten
                      pg_conn.exec("UNLISTEN #{pg_conn.escape_identifier channel}")
                    when :shutdown
                      throw :shutdown
                    end
                  end

                  pg_conn.wait_for_notify(1) do |chan, pid, message|
                    broadcast(chan, message)
                  end
                end
              end
            end
          end

          def shutdown
            @queue.push([:shutdown])
            Thread.pass while @thread.alive?
          end

          def add_channel(channel, on_success)
            @queue.push([:listen, channel, on_success])
          end

          def remove_channel(channel)
            @queue.push([:unlisten, channel])
          end

          def invoke_callback(*)
            @event_loop.post { super }
          end
        end
    end
  end
end
