gem 'pg', '~> 0.18'
require 'pg'
require 'thread'

module ActionCable
  module SubscriptionAdapter
    class PostgreSQL < Base # :nodoc:
      def broadcast(channel, payload)
        with_connection do |pg_conn|
          pg_conn.exec("NOTIFY #{pg_conn.escape_identifier(channel)}, '#{pg_conn.escape_string(payload)}'")
        end
      end

      def subscribe(channel, callback, success_callback = nil)
        listener.subscribe_to(channel, callback, success_callback)
      end

      def unsubscribe(channel, callback)
        listener.unsubscribe_from(channel, callback)
      end

      def with_connection(&block) # :nodoc:
        ActiveRecord::Base.connection_pool.with_connection do |ar_conn|
          pg_conn = ar_conn.raw_connection

          unless pg_conn.is_a?(PG::Connection)
            raise 'ActiveRecord database must be Postgres in order to use the Postgres ActionCable storage adapter'
          end

          yield pg_conn
        end
      end

      private
        def listener
          @listener ||= Listener.new(self)
        end

        class Listener
          def initialize(adapter)
            @adapter = adapter
            @subscribers = Hash.new { |h,k| h[k] = [] }
            @sync = Mutex.new
            @queue = Queue.new

            Thread.new do
              Thread.current.abort_on_exception = true
              listen
            end
          end

          def listen
            @adapter.with_connection do |pg_conn|
              loop do
                until @queue.empty?
                  action, channel, callback = @queue.pop(true)
                  escaped_channel = pg_conn.escape_identifier(channel)

                  if action == :listen
                    pg_conn.exec("LISTEN #{escaped_channel}")
                    ::EM.next_tick(&callback) if callback
                  elsif action == :unlisten
                    pg_conn.exec("UNLISTEN #{escaped_channel}")
                  end
                end

                pg_conn.wait_for_notify(1) do |chan, pid, message|
                  @subscribers[chan].each do |callback|
                    ::EM.next_tick { callback.call(message) }
                  end
                end
              end
            end
          end

          def subscribe_to(channel, callback, success_callback)
            @sync.synchronize do
              if @subscribers[channel].empty?
                @queue.push([:listen, channel, success_callback])
              end

              @subscribers[channel] << callback
            end
          end

          def unsubscribe_from(channel, callback)
            @sync.synchronize do
              @subscribers[channel].delete(callback)

              if @subscribers[channel].empty?
                @queue.push([:unlisten, channel])
              end
            end
          end
        end
    end
  end
end
