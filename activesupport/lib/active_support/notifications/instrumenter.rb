require 'active_support/secure_random'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  module Notifications
    class Instrumenter
      def initialize(notifier)
        @id = unique_id
        @notifier = notifier
      end

      def instrument(name, payload={})
        time = Time.now
        yield if block_given?
      ensure
        @notifier.publish(name, time, Time.now, @id, payload)
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
