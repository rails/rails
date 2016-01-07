require 'thread'

module ActionCable
  module StorageAdapter
    class Postgres < Base
      # The storage instance used for broadcasting. Not intended for direct user use.
      def broadcast
        @broadcast ||= PostgresWrapper.new
      end

      def pubsub
        PostgresWrapper.new
      end

      class Listener
        include Singleton

        attr_accessor :subscribers

        def initialize
          @subscribers = Hash.new {|h,k| h[k] = [] }
          @sync = Mutex.new
          @queue = Queue.new

          Thread.new do
            Thread.current.abort_on_exception = true
            listen
          end
        end

        def listen
          ActiveRecord::Base.connection_pool.with_connection do |ar_conn|
            pg_conn = ar_conn.raw_connection

            loop do
              until @queue.empty?
                value = @queue.pop(true)
                if value.first == :listen
                  pg_conn.exec("LISTEN #{value[1]}")
                elsif value.first == :unlisten
                  pg_conn.exec("UNLISTEN #{value[1]}")
                end
              end

              pg_conn.wait_for_notify(1) do |chan, pid, message|
                @subscribers[chan].each do |callback|
                  callback.call(message)
                end
              end
            end
          end
        end

        def subscribe_to(channel, callback)
          @sync.synchronize do
            if @subscribers[channel].empty?
              @queue.push([:listen, channel])
            end

            @subscribers[channel] << callback
          end
        end

        def unsubscribe_to(channel, callback = nil)
          @sync.synchronize do
            if callback
              @subscribers[channel].delete(callback)
            else
              @subscribers.delete(channel)
            end

            if @subscribers[channel].empty?
              @queue.push([:unlisten, channel])
            end
          end
        end
      end

      class PostgresWrapper
        def publish(channel, message)
          ActiveRecord::Base.connection_pool.with_connection do |ar_conn|
            pg_conn = ar_conn.raw_connection

            unless pg_conn.is_a?(PG::Connection)
              raise 'ActiveRecord database must be Postgres in order to use the Postgres ActionCable storage adapter'
            end

            pg_conn.exec("NOTIFY #{channel}, '#{message}'")
          end
        end

        def subscribe(channel, &callback)
          Listener.instance.subscribe_to(channel, callback)
          # Needed for channel/streams.rb#L79
          ::EM::DefaultDeferrable.new
        end

        def unsubscribe(channel)
          Listener.instance.unsubscribe_to(channel)
        end

        def unsubscribe_proc(channel, block)
          Listener.instance.unsubscribe_to(channel, block)
        end
      end

    end
  end
end
