# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "securerandom"

module ActiveSupport
  module Notifications
    # Instrumenters are stored in a thread local.
    class Instrumenter
      attr_reader :id

      def initialize(notifier)
        unless notifier.respond_to?(:build_handle)
          notifier = LegacyHandle::Wrapper.new(notifier)
        end

        @id       = unique_id
        @notifier = notifier
      end

      class LegacyHandle # :nodoc:
        class Wrapper # :nodoc:
          def initialize(notifier)
            @notifier = notifier
          end

          def build_handle(name, id, payload)
            LegacyHandle.new(@notifier, name, id, payload)
          end

          delegate :start, :finish, to: :@notifier
        end

        def initialize(notifier, name, id, payload)
          @notifier = notifier
          @name = name
          @id = id
          @payload = payload
        end

        def start
          @listener_state = @notifier.start @name, @id, @payload
        end

        def finish
          @notifier.finish(@name, @id, @payload, @listener_state)
        end
      end

      # Given a block, instrument it by measuring the time taken to execute
      # and publish it. Without a block, simply send a message via the
      # notifier. Notice that events get sent even if an error occurs in the
      # passed-in block.
      def instrument(name, payload = {})
        handle = build_handle(name, payload)
        handle.start
        begin
          yield payload if block_given?
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          payload[:exception_object] = e
          raise e
        ensure
          handle.finish
        end
      end

      # Returns a "handle" for an event with the given +name+ and +payload+.
      #
      # #start and #finish must each be called exactly once on the returned object.
      #
      # Where possible, it's best to use #instrument, which will record the
      # start and finish of the event and correctly handle any exceptions.
      # +build_handle+ is a low-level API intended for cases where using
      # +instrument+ isn't possible.
      #
      # See ActiveSupport::Notifications::Fanout::Handle.
      def build_handle(name, payload)
        @notifier.build_handle(name, @id, payload)
      end

      def new_event(name, payload = {}) # :nodoc:
        Event.new(name, nil, nil, @id, payload)
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
      attr_reader :name, :transaction_id
      attr_accessor :payload

      def initialize(name, start, ending, transaction_id, payload)
        @name           = name
        @payload        = payload.dup
        @time           = start ? start.to_f * 1_000.0 : start
        @transaction_id = transaction_id
        @end            = ending ? ending.to_f * 1_000.0 : ending
        @cpu_time_start = 0.0
        @cpu_time_finish = 0.0
        @allocation_count_start = 0
        @allocation_count_finish = 0
        @gc_time_start = 0
        @gc_time_finish = 0
      end

      def time
        @time / 1000.0 if @time
      end

      def end
        @end / 1000.0 if @end
      end

      def record # :nodoc:
        start!
        begin
          yield payload if block_given?
        rescue Exception => e
          payload[:exception] = [e.class.name, e.message]
          payload[:exception_object] = e
          raise e
        ensure
          finish!
        end
      end

      # Record information at the time this event starts
      def start!
        @time = now
        @cpu_time_start = now_cpu
        @gc_time_start = now_gc
        @allocation_count_start = now_allocations
      end

      # Record information at the time this event finishes
      def finish!
        @cpu_time_finish = now_cpu
        @gc_time_finish = now_gc
        @end = now
        @allocation_count_finish = now_allocations
      end

      # Returns the CPU time (in milliseconds) passed between the call to
      # #start! and the call to #finish!.
      def cpu_time
        @cpu_time_finish - @cpu_time_start
      end

      # Returns the idle time time (in milliseconds) passed between the call to
      # #start! and the call to #finish!.
      def idle_time
        diff = duration - cpu_time
        diff > 0.0 ? diff : 0.0
      end

      # Returns the number of allocations made between the call to #start! and
      # the call to #finish!.
      def allocations
        @allocation_count_finish - @allocation_count_start
      end

      # Returns the time spent in GC (in milliseconds) between the call to #start!
      # and the call to #finish!
      def gc_time
        (@gc_time_finish - @gc_time_start) / 1_000_000.0
      end

      # Returns the difference in milliseconds between when the execution of the
      # event started and when it ended.
      #
      #   ActiveSupport::Notifications.subscribe('wait') do |event|
      #     @event = event
      #   end
      #
      #   ActiveSupport::Notifications.instrument('wait') do
      #     sleep 1
      #   end
      #
      #   @event.duration # => 1000.138
      def duration
        @end - @time
      end

      private
        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
        end

        begin
          Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID, :float_millisecond)

          def now_cpu
            Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID, :float_millisecond)
          end
        rescue
          def now_cpu
            0.0
          end
        end

        if GC.respond_to?(:total_time)
          def now_gc
            GC.total_time
          end
        else
          def now_gc
            0
          end
        end

        if GC.stat.key?(:total_allocated_objects)
          def now_allocations
            GC.stat(:total_allocated_objects)
          end
        else # Likely on JRuby, TruffleRuby
          def now_allocations
            0
          end
        end
    end
  end
end
