require 'thread'

begin
  require 'pg'
rescue Gem::LoadError => e
  raise Gem::LoadError, "You are trying to use the PostgreSQL ActionCable adapter, but do not have the proper gems installed. Add `gem 'pg'` to your Gemfile (and ensure its version is at the minimum required by ActionCable)."
end

module ActionCable
  module StorageAdapter
    class PostgreSQL < Base
      # The storage instance used for broadcasting. Not intended for direct user use.
      def broadcast(channel, payload)
        with_connection do |pg_conn|
          pg_conn.exec("NOTIFY #{channel}, '#{payload}'")
        end
      end

      def subscribe(channel, callback, success_callback = nil)
        listener.subscribe_to(channel, callback, success_callback)
      end

      def unsubscribe(channel, callback)
        listener.unsubscribe_to(channel, callback)
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
                  value = @queue.pop(true)
                  if value.first == :listen
                    pg_conn.exec("LISTEN #{value[1]}")
                    ::EM.next_tick(&value[2]) if value[2]
                  elsif value.first == :unlisten
                    pg_conn.exec("UNLISTEN #{value[1]}")
                  end

                  pg_conn.wait_for_notify(1) do |chan, pid, message|
                    @subscribers[chan].each do |callback|
                      ::EM.next_tick { callback.call(message) }
                    end
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

          def unsubscribe_to(channel, callback)
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
