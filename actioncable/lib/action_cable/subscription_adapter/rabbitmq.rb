# frozen_string_literal: true

gem "bunny", ">= 2", "< 3"
require "bunny"
require "json"

module ActionCable
  module SubscriptionAdapter
    class RabbitMQ < Base # :nodoc:
      prepend ChannelPrefix

      def initialize(*)
        super
        @listener = nil
      end

      def broadcast(channel, payload)
        listener.publish_to_rabbitmq(channel, payload)
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

      private
        def listener
          @listener || @server.mutex.synchronize { @listener ||= Listener.new(self) }
        end

        class Listener < SubscriberMap
          def initialize(adapter)
            super()
            @subscription_lock = Mutex.new
            @rabbit_mq_config = adapter.server.config.cable
            listen
          end

          def publish_to_rabbitmq(channel, payload)
            exchange.publish({ "channel" => channel, "payload" => payload }.to_json)
          end

          def shutdown
            @queue_channel.close if @queue_channel
            @cable_channel.close if @cable_channel
            bunny_connection.close if bunny_connection
          end

          private
            def listen
              @queue_channel = bunny_connection.create_channel
              queue = @queue_channel.queue("", exclusive: true)
              queue.bind exchange
              begin
                queue.subscribe do |_delivery_info, _properties, body|
                  body = JSON.parse(body)
                  channel = body["channel"]
                  payload = body["payload"]

                  broadcast channel, payload
                end
              rescue Interrupt => _
                @queue_channel.close if @queue_channel
                bunny_connection.close if bunny_connection
              end
            end

            def bunny_connection
              @_bunny_conn || @subscription_lock.synchronize do
                @_bunny_conn ||= Bunny.new @rabbit_mq_config
                @_bunny_conn.start
              end
            end

            def exchange
              @_exchange || @subscription_lock.synchronize do
                @_exchange ||= begin
                  @cable_channel = bunny_connection.create_channel
                  @cable_channel.fanout("_action_cable_internal")
                end
              end
            end
        end
    end
  end
end
