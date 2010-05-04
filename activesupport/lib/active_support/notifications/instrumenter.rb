require 'active_support/secure_random'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  module Notifications
    class Instrumenter
      attr_reader :id

      def initialize(notifier)
        @id = unique_id
        @notifier = notifier
      end

      # Instrument the given block by measuring the time taken to execute it
      # and publish it. Notice that events get sent even if an error occurs
      # in the passed-in block
      def instrument(name, payload={})
        time = Time.now
        begin
          yield(payload) if block_given?
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          raise e
        ensure
          @notifier.publish(name, time, Time.now, @id, payload)
        end
      end

      private
        def unique_id
          SecureRandom.hex(10)
        end
    end

    class Event
      attr_reader :name, :time, :end, :transaction_id, :payload

      def initialize(name, start, ending, transaction_id, payload)
        @name           = name
        @payload        = payload.dup
        @time           = start
        @transaction_id = transaction_id
        @end            = ending
      end

      def duration
        @duration ||= 1000.0 * (@end - @time)
      end

      def parent_of?(event)
        start = (self.time - event.time) * 1000
        start <= 0 && (start + duration >= event.duration)
      end
    end
  end
end
