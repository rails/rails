require 'securerandom'

module ActiveSupport
  module Notifications
    # Instrumenters are stored in a thread local.
    class Instrumenter
      attr_reader :id

      def initialize(notifier)
        @id       = unique_id
        @notifier = notifier
      end

      # Instrument the given block by measuring the time taken to execute it
      # and publish it. Notice that events get sent even if an error occurs
      # in the passed-in block.
      def instrument(name, payload={})
        # some of the listeners might have state
        listeners_state = start name, payload
        begin
          yield payload
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          payload[:exception_object] = e
          raise e
        ensure
          finish_with_state listeners_state, name, payload
        end
      end

      # Send a start notification with +name+ and +payload+.
      def start(name, payload)
        @notifier.start name, @id, payload
      end

      # Send a finish notification with +name+ and +payload+.
      def finish(name, payload)
        @notifier.finish name, @id, payload
      end

      def finish_with_state(listeners_state, name, payload)
        @notifier.finish name, @id, payload, listeners_state
      end

      private

      def unique_id
        SecureRandom.hex(10)
      end
    end

    class Event
      attr_reader :name, :time, :transaction_id, :payload, :children
      attr_accessor :end

      def initialize(name, start, ending, transaction_id, payload)
        @name           = name
        @payload        = payload.dup
        @time           = start
        @transaction_id = transaction_id
        @end            = ending
        @children       = []
        @duration       = nil
      end

      # Returns the difference in milliseconds between when the execution of the
      # event started and when it ended.
      #
      #   ActiveSupport::Notifications.subscribe('wait') do |*args|
      #     @event = ActiveSupport::Notifications::Event.new(*args)
      #   end
      #
      #   ActiveSupport::Notifications.instrument('wait') do
      #     sleep 1
      #   end
      #
      #   @event.duration # => 1000.138
      def duration
        @duration ||= 1000.0 * (self.end - time)
      end

      def <<(event)
        @children << event
      end

      def parent_of?(event)
        @children.include? event
      end
    end
  end
end
