require 'active_support/core_ext/module/delegation'

module ActiveSupport
  module Notifications
    class Instrumenter
      attr_reader :id

      def initialize(notifier)
        @id = unique_id
        @notifier = notifier
        @entry_index = 0
        @exit_index = 0
        @stack_level = 0
      end

      # Instrument the given block by measuring the time taken to execute it
      # and publish it. Notice that events get sent even if an error occurs
      # in the passed-in block
      def instrument(name, payload={})
        started = Time.now
        payload[:entry_index] = enter_instrumentation

        begin
          yield 
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          raise e
        ensure
          payload[:exit_index] = exit_instrumentation
          @notifier.publish(name, started, Time.now, @id, payload)
        end
      end

      private
        def unique_id
          SecureRandom.hex(10)
        end

        def enter_instrumentation
          @stack_level += 1
          @entry_index += 1
        end

        def exit_instrumentation
          idx = @exit_index += 1
          @stack_level -= 1
          if @stack_level == 0
            @entry_index = 0
            @exit_index = 0
          end
          idx
        end
    end

    class Event
      attr_reader :name, :time, :end, :transaction_id, :payload, :duration

      def initialize(name, start, ending, transaction_id, payload)
        @name           = name
        @payload        = payload.dup
        @time           = start
        @transaction_id = transaction_id
        @end            = ending
        @duration       = 1000.0 * (@end - @time)
      end

      def parent_of?(event)
        start = (time - event.time) * 1000
        start <= 0 && (start + duration >= event.duration) &&
          @payload[:entry_index] < event.payload[:entry_index] &&
          @payload[:exit_index] > event.payload[:exit_index]
      end
    end
  end
end
