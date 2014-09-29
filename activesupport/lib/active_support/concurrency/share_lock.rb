require 'thread'
require 'monitor'

module ActiveSupport
  module Concurrency
    class ShareLock
      include MonitorMixin

      # We track Thread objects, instead of just using counters, because
      # we need exclusive locks to be reentrant, and we need to be able
      # to upgrade share locks to exclusive.


      # If +loose_upgrades+ is false (the default), then a thread that
      # is waiting on an Exclusive lock will continue to hold any Share
      # lock that it has already established. This is safer, but can
      # lead to deadlock.
      #
      # If +loose_upgrades+ is true, a thread waiting on an Exclusive
      # lock will temporarily relinquish its Share lock. Being less
      # strict, this behavior prevents some classes of deadlocks. For
      # many resources, loose upgrades are sufficient: if a thread is
      # awaiting a lock, it is not running any other code.
      attr_reader :loose_upgrades

      def initialize(loose_upgrades = false)
        @loose_upgrades = loose_upgrades

        super()

        @cv = new_cond

        @sharing = Hash.new(0)
        @exclusive_thread = nil
        @exclusive_depth = 0
      end

      def start_exclusive(no_wait=false)
        synchronize do
          unless @exclusive_thread == Thread.current
            return false if no_wait && busy?

            loose_shares = nil
            if @loose_upgrades
              loose_shares = @sharing.delete(Thread.current)
            end

            @cv.wait_while { busy? } if busy?

            @exclusive_thread = Thread.current
            @sharing[Thread.current] = loose_shares if loose_shares
          end
          @exclusive_depth += 1

          true
        end
      end

      def stop_exclusive
        synchronize do
          raise "invalid unlock" if @exclusive_thread != Thread.current

          @exclusive_depth -= 1
          if @exclusive_depth == 0
            @exclusive_thread = nil
            @cv.broadcast
          end
        end
      end

      def start_sharing
        synchronize do
          if @exclusive_thread && @exclusive_thread != Thread.current
            @cv.wait_while { @exclusive_thread }
          end
          @sharing[Thread.current] += 1
        end
      end

      def stop_sharing
        synchronize do
          if @sharing[Thread.current] > 1
            @sharing[Thread.current] -= 1
          else
            @sharing.delete Thread.current
            @cv.broadcast
          end
        end
      end

      def exclusive(no_wait=false)
        if start_exclusive(no_wait)
          begin
            yield
          ensure
            stop_exclusive
          end
        end
      end

      def sharing
        start_sharing
        begin
          yield
        ensure
          stop_sharing
        end
      end

      private

      def busy?
        (@exclusive_thread && @exclusive_thread != Thread.current) ||
          @sharing.size > (@sharing[Thread.current] > 0 ? 1 : 0)
      end
    end
  end
end
