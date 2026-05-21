# frozen_string_literal: true

require "monitor"
require "active_support/isolated_execution_state"

module ActiveSupport
  module Concurrency
    # A share/exclusive lock, otherwise known as a read/write lock.
    #
    # https://en.wikipedia.org/wiki/Readers%E2%80%93writer_lock
    class ShareLock
      include MonitorMixin

      # We track execution-context objects (Threads or Fibers, depending on
      # +ActiveSupport::IsolatedExecutionState.isolation_level+), instead of
      # just using counters, because we need exclusive locks to be reentrant,
      # and we need to be able to upgrade share locks to exclusive.

      def raw_state # :nodoc:
        synchronize do
          owners = @sleeping.keys | @sharing.keys | @waiting.keys
          owners |= [@exclusive_owner] if @exclusive_owner

          data = {}

          owners.each do |owner|
            purpose, compatible = @waiting[owner]

            data[owner] = {
              owner: owner,
              sharing: @sharing[owner],
              exclusive: @exclusive_owner == owner,
              purpose: purpose,
              compatible: compatible,
              waiting: !!@waiting[owner],
              sleeper: @sleeping[owner],
            }
          end

          # NB: Yields while holding our *internal* synchronize lock,
          # which is supposed to be used only for a few instructions at
          # a time. This allows the caller to inspect additional state
          # without things changing out from underneath, but would have
          # disastrous effects upon normal operation. Fortunately, this
          # method is only intended to be called when things have
          # already gone wrong.
          yield data
        end
      end

      def initialize
        super()

        @cv = new_cond

        @sharing = Hash.new(0)
        @waiting = {}
        @sleeping = {}
        @exclusive_owner = nil
        @exclusive_depth = 0
      end

      # Returns false if +no_wait+ is set and the lock is not
      # immediately available. Otherwise, returns true after the lock
      # has been acquired.
      #
      # +purpose+ and +compatible+ work together; while this owner is
      # waiting for the exclusive lock, it will yield its share (if any)
      # to any other attempt whose +purpose+ appears in this attempt's
      # +compatible+ list. This allows a "loose" upgrade, which, being
      # less strict, prevents some classes of deadlocks.
      #
      # For many resources, loose upgrades are sufficient: if an owner
      # is awaiting a lock, it is not running any other code. With
      # +purpose+ matching, it is possible to yield only to other
      # owners whose activity will not interfere.
      def start_exclusive(purpose: nil, compatible: [], no_wait: false)
        synchronize do
          unless @exclusive_owner == current_owner
            if busy_for_exclusive?(purpose)
              return false if no_wait

              yield_shares(purpose: purpose, compatible: compatible, block_share: true) do
                wait_for(:start_exclusive) { busy_for_exclusive?(purpose) }
              end
            end
            @exclusive_owner = current_owner
          end
          @exclusive_depth += 1

          true
        end
      end

      # Relinquish the exclusive lock. Must only be called by the owner
      # that called start_exclusive (and currently holds the lock).
      def stop_exclusive(compatible: [])
        synchronize do
          raise "invalid unlock" if @exclusive_owner != current_owner

          @exclusive_depth -= 1
          if @exclusive_depth == 0
            @exclusive_owner = nil

            if eligible_waiters?(compatible)
              yield_shares(compatible: compatible, block_share: true) do
                wait_for(:stop_exclusive) { @exclusive_owner || eligible_waiters?(compatible) }
              end
            end
            @cv.broadcast
          end
        end
      end

      def start_sharing
        synchronize do
          owner = current_owner
          if @sharing[owner] > 0 || @exclusive_owner == owner
            # We already hold a lock; nothing to wait for
          elsif @waiting[owner]
            # We're nested inside a +yield_shares+ call: we'll resume as
            # soon as there isn't an exclusive lock in our way
            wait_for(:start_sharing) { @exclusive_owner }
          else
            # This is an initial / outermost share call: any outstanding
            # requests for an exclusive lock get to go first
            wait_for(:start_sharing) { busy_for_sharing?(false) }
          end
          @sharing[owner] += 1
        end
      end

      def stop_sharing
        synchronize do
          owner = current_owner
          if @sharing[owner] > 1
            @sharing[owner] -= 1
          else
            @sharing.delete owner
            @cv.broadcast
          end
        end
      end

      # Execute the supplied block while holding the Exclusive lock. If
      # +no_wait+ is set and the lock is not immediately available,
      # returns +nil+ without yielding. Otherwise, returns the result of
      # the block.
      #
      # See +start_exclusive+ for other options.
      def exclusive(purpose: nil, compatible: [], after_compatible: [], no_wait: false)
        if start_exclusive(purpose: purpose, compatible: compatible, no_wait: no_wait)
          begin
            yield
          ensure
            stop_exclusive(compatible: after_compatible)
          end
        end
      end

      # Execute the supplied block while holding the Share lock.
      def sharing
        start_sharing
        begin
          yield
        ensure
          stop_sharing
        end
      end

      # Temporarily give up all held Share locks while executing the
      # supplied block, allowing any +compatible+ exclusive lock request
      # to proceed.
      def yield_shares(purpose: nil, compatible: [], block_share: false)
        loose_shares = previous_wait = nil
        owner = current_owner
        synchronize do
          if loose_shares = @sharing.delete(owner)
            if previous_wait = @waiting[owner]
              purpose = nil unless purpose == previous_wait[0]
              compatible &= previous_wait[1]
            end
            compatible |= [false] unless block_share
            @waiting[owner] = [purpose, compatible]
          end

          @cv.broadcast
        end

        begin
          yield
        ensure
          synchronize do
            wait_for(:yield_shares) { @exclusive_owner && @exclusive_owner != owner }

            if previous_wait
              @waiting[owner] = previous_wait
            else
              @waiting.delete owner
            end
            @sharing[owner] = loose_shares if loose_shares
          end
        end
      end

      private
        def current_owner
          ActiveSupport::IsolatedExecutionState.context
        end

        # Must be called within synchronize
        def busy_for_exclusive?(purpose)
          busy_for_sharing?(purpose) ||
            @sharing.size > (@sharing[current_owner] > 0 ? 1 : 0)
        end

        def busy_for_sharing?(purpose)
          owner = current_owner
          (@exclusive_owner && @exclusive_owner != owner) ||
            @waiting.any? { |o, (_, c)| o != owner && !c.include?(purpose) }
        end

        def eligible_waiters?(compatible)
          @waiting.any? { |o, (p, _)| compatible.include?(p) && @waiting.all? { |o2, (_, c2)| o == o2 || c2.include?(p) } }
        end

        def wait_for(method, &block)
          owner = current_owner
          @sleeping[owner] = method
          @cv.wait_while(&block)
        ensure
          @sleeping.delete owner
        end
    end
  end
end
