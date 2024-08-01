# frozen_string_literal: true

require "thread"
require "monitor"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      # = Active Record Connection Pool \Queue
      #
      # Threadsafe, fair, LIFO queue.  Meant to be used by ConnectionPool
      # with which it shares a Monitor.
      class Queue
        def initialize(lock = Monitor.new)
          @lock = lock
          @cond = @lock.new_cond
          @num_waiting = 0
          @queue = []
        end

        # Test if any threads are currently waiting on the queue.
        def any_waiting?
          synchronize do
            @num_waiting > 0
          end
        end

        # Returns the number of threads currently waiting on this
        # queue.
        def num_waiting
          synchronize do
            @num_waiting
          end
        end

        # Add +element+ to the queue.  Never blocks.
        def add(element)
          synchronize do
            @queue.push element
            @cond.signal
          end
        end

        # If +element+ is in the queue, remove and return it, or +nil+.
        def delete(element)
          synchronize do
            @queue.delete(element)
          end
        end

        # Remove all elements from the queue.
        def clear
          synchronize do
            @queue.clear
          end
        end

        # Remove the head of the queue.
        #
        # If +timeout+ is not given, remove and return the head of the
        # queue if the number of available elements is strictly
        # greater than the number of threads currently waiting (that
        # is, don't jump ahead in line).  Otherwise, return +nil+.
        #
        # If +timeout+ is given, block if there is no element
        # available, waiting up to +timeout+ seconds for an element to
        # become available.
        #
        # Raises:
        # - ActiveRecord::ConnectionTimeoutError if +timeout+ is given and no element
        # becomes available within +timeout+ seconds,
        def poll(timeout = nil)
          synchronize { internal_poll(timeout) }
        end

        private
          def internal_poll(timeout)
            no_wait_poll || (timeout && wait_poll(timeout))
          end

          def synchronize(&block)
            @lock.synchronize(&block)
          end

          # Test if the queue currently contains any elements.
          def any?
            !@queue.empty?
          end

          # A thread can remove an element from the queue without
          # waiting if and only if the number of currently available
          # connections is strictly greater than the number of waiting
          # threads.
          def can_remove_no_wait?
            @queue.size > @num_waiting
          end

          # Removes and returns the head of the queue if possible, or +nil+.
          def remove
            @queue.pop
          end

          # Remove and return the head of the queue if the number of
          # available elements is strictly greater than the number of
          # threads currently waiting.  Otherwise, return +nil+.
          def no_wait_poll
            remove if can_remove_no_wait?
          end

          # Waits on the queue up to +timeout+ seconds, then removes and
          # returns the head of the queue.
          def wait_poll(timeout)
            @num_waiting += 1

            t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            elapsed = 0
            loop do
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                @cond.wait(timeout - elapsed)
              end

              return remove if any?

              elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
              if elapsed >= timeout
                msg = "could not obtain a connection from the pool within %0.3f seconds (waited %0.3f seconds); all pooled connections were in use" %
                  [timeout, elapsed]
                raise ConnectionTimeoutError, msg
              end
            end
          ensure
            @num_waiting -= 1
          end
      end

      # Adds the ability to turn a basic fair FIFO queue into one
      # biased to some thread.
      module BiasableQueue # :nodoc:
        class BiasedConditionVariable # :nodoc:
          # semantics of condition variables guarantee that +broadcast+, +broadcast_on_biased+,
          # +signal+ and +wait+ methods are only called while holding a lock
          def initialize(lock, other_cond, preferred_thread)
            @real_cond = lock.new_cond
            @other_cond = other_cond
            @preferred_thread = preferred_thread
            @num_waiting_on_real_cond = 0
          end

          def broadcast
            broadcast_on_biased
            @other_cond.broadcast
          end

          def broadcast_on_biased
            @num_waiting_on_real_cond = 0
            @real_cond.broadcast
          end

          def signal
            if @num_waiting_on_real_cond > 0
              @num_waiting_on_real_cond -= 1
              @real_cond
            else
              @other_cond
            end.signal
          end

          def wait(timeout)
            if Thread.current == @preferred_thread
              @num_waiting_on_real_cond += 1
              @real_cond
            else
              @other_cond
            end.wait(timeout)
          end
        end

        def with_a_bias_for(thread)
          previous_cond = nil
          new_cond      = nil
          synchronize do
            previous_cond = @cond
            @cond = new_cond = BiasedConditionVariable.new(@lock, @cond, thread)
          end
          yield
        ensure
          synchronize do
            @cond = previous_cond if previous_cond
            new_cond.broadcast_on_biased if new_cond # wake up any remaining sleepers
          end
        end
      end

      # Connections must be leased while holding the main pool mutex. This is
      # an internal subclass that also +.leases+ returned connections while
      # still in queue's critical section (queue synchronizes with the same
      # <tt>@lock</tt> as the main pool) so that a returned connection is already
      # leased and there is no need to re-enter synchronized block.
      class ConnectionLeasingQueue < Queue # :nodoc:
        include BiasableQueue

        private
          def internal_poll(timeout)
            conn = super
            conn.lease if conn
            conn
          end
      end
    end
  end
end
