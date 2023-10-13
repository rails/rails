# frozen_string_literal: true

gem "pg", "~> 1.1"
require "pg"
require "openssl"

module ActionCable
  module SubscriptionAdapter
    class PostgreSQL < Base # :nodoc:
      prepend ChannelPrefix

      PayloadTooLargeError = Class.new(StandardError)

      MAX_NOTIFY_SIZE = 7997 # documented as 8000 bytes, but there appears to be some overhead in transit
      DEFAULT_LARGE_PAYLOADS_TABLE = "action_cable_large_payloads"
      LARGE_PAYLOAD_PREFIX = "__large_payload:"

      attr_reader :large_payloads_table

      def initialize(*)
        super
        @listener = nil
        @large_payloads_table = @server.config.cable[:large_payloads_table] || DEFAULT_LARGE_PAYLOADS_TABLE
        @insert_large_payload_query = "INSERT INTO #{@large_payloads_table} (payload) VALUES ($1) RETURNING id"
      end

      def broadcast(channel, payload)
        with_broadcast_connection do |pg_conn|
          channel = pg_conn.escape_identifier(channel_identifier(channel))
          payload = pg_conn.escape_string(payload)

          if payload.bytesize > MAX_NOTIFY_SIZE
            payload_id = insert_large_payload(pg_conn, payload)
            payload = "#{LARGE_PAYLOAD_PREFIX}#{payload_id}"
          end

          pg_conn.exec("NOTIFY #{channel}, '#{payload}'")
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
          channel.size > 63 ? OpenSSL::Digest::SHA1.hexdigest(channel) : channel
        end

        def listener
          @listener || @server.mutex.synchronize { @listener ||= Listener.new(self, @server.event_loop) }
        end

        def insert_large_payload(pg_conn, payload)
          result = pg_conn.exec_params(@insert_large_payload_query, [payload])
          result.first.fetch("id")
        rescue PG::UndefinedTable
          raise PayloadTooLargeError, "The payload is too large for PostgreSQL NOTIFY (#{payload.bytesize} / #{MAX_NOTIFY_SIZE} bytes) and the #{@large_payloads_table} table does not exist. See documentation at https://edgeguides.rubyonrails.org/action_cable_overview.html#postgresql-adapter for details."
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
            @select_large_payload_query = "SELECT payload FROM #{adapter.large_payloads_table} WHERE id = $1"

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

          def invoke_callback(callback, message)
            if message.start_with?(LARGE_PAYLOAD_PREFIX)
              id = message.delete_prefix(LARGE_PAYLOAD_PREFIX)
              ActiveRecord::Base.connection_pool.with_connection do |connection|
                result = connection.raw_connection.exec_params(@select_large_payload_query, [id])
                message = result.first.fetch("payload")
              end
            end

            @event_loop.post { super }
          end
        end
    end
  end
end
