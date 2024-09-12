# frozen_string_literal: true

require "concurrent/atomic/atomic_boolean"
require "concurrent/atomic/read_write_lock"

module ActiveRecord
  class AsynchronousQueriesTracker # :nodoc:
    class Session # :nodoc:
      def initialize
        @active = Concurrent::AtomicBoolean.new(true)
        @lock = Concurrent::ReadWriteLock.new
      end

      def active?
        @active.true?
      end

      def synchronize(&block)
        @lock.with_read_lock(&block)
      end

      def finalize(wait = false)
        @active.make_false
        if wait
          # Wait until all thread with a read lock are done
          @lock.with_write_lock { }
        end
      end
    end

    class << self
      def install_executor_hooks(executor = ActiveSupport::Executor)
        executor.register_hook(self)
      end

      def run
        ActiveRecord::Base.asynchronous_queries_tracker.tap(&:start_session)
      end

      def complete(asynchronous_queries_tracker)
        asynchronous_queries_tracker.finalize_session
      end
    end

    def initialize
      @stack = []
    end

    def current_session
      @stack.last or raise ActiveRecordError, "Can't perform asynchronous queries without a query session"
    end

    def start_session
      session = Session.new
      @stack << session
    end

    def finalize_session(wait = false)
      session = @stack.pop
      session&.finalize(wait)
      self
    end
  end
end
