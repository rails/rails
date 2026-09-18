# :markup: markdown
# frozen_string_literal: true

module ActiveSupport
  module Concurrency
    class ThreadMonitor # :nodoc:
      # Raised when +timeout+ is set and the monitor could not be entered in
      # time. The message is supplied by the caller, which knows what the
      # monitor is guarding and therefore what the wait means.
      class TimeoutError < StandardError; end

      EXCEPTION_NEVER = { Exception => :never }.freeze
      EXCEPTION_IMMEDIATE = { Exception => :immediate }.freeze
      POLL_INTERVAL = 0.01
      private_constant :EXCEPTION_NEVER, :EXCEPTION_IMMEDIATE, :POLL_INTERVAL

      # When +timeout+ is given, waiting to enter the monitor for longer than
      # that many seconds raises TimeoutError with +timeout_message+ instead of
      # waiting forever.
      def initialize(timeout: nil, timeout_message: nil)
        @owner = nil
        @count = 0
        @mutex = Mutex.new
        @timeout = timeout
        @timeout_message = timeout_message
      end

      def synchronize(&block)
        Thread.handle_interrupt(EXCEPTION_NEVER) do
          mon_enter

          begin
            Thread.handle_interrupt(EXCEPTION_IMMEDIATE, &block)
          ensure
            mon_exit
          end
        end
      end

      private
        def mon_enter
          if @owner != Thread.current
            if @timeout
              acquire_with_timeout
            else
              @mutex.lock
            end
          end
          @owner = Thread.current
          @count += 1
        end

        # Only polls when the monitor is actually contended: the first #try_lock
        # succeeds in the uncontended case, which is the one that matters for
        # throughput.
        def acquire_with_timeout
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout

          until @mutex.try_lock
            if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
              raise TimeoutError, @timeout_message
            end
            sleep POLL_INTERVAL
          end
        end

        def mon_exit
          unless @owner == Thread.current
            raise ThreadError, "current thread not owner"
          end

          @count -= 1
          return unless @count == 0
          @owner = nil
          @mutex.unlock
        end
    end
  end
end
