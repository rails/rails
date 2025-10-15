# frozen_string_literal: true

module ActiveSupport
  module Concurrency
    class ThreadMonitor # :nodoc:
      EXCEPTION_NEVER = { Exception => :never }.freeze
      EXCEPTION_IMMEDIATE = { Exception => :immediate }.freeze
      private_constant :EXCEPTION_NEVER, :EXCEPTION_IMMEDIATE

      def initialize
        @owner = nil
        @count = 0
        @mutex = Mutex.new
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
        def mon_try_enter
          if @owner != Thread.current
            return false unless @mutex.try_lock
            @owner = Thread.current
          end
          @count += 1
        end

        def mon_enter
          @mutex.lock if @owner != Thread.current
          @owner = Thread.current
          @count += 1
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
