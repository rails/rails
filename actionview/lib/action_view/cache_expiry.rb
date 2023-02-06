# frozen_string_literal: true

require "thread"

module ActionView
  class CacheExpiry
    class ExecutionLock
      def initialize
        @guard = Thread::Mutex.new
        @condition = Thread::ConditionVariable.new

        @read_count = 0
        @write_count = 0

        # This stores per-EC the number of read locks held by the EC.
        # It's used to figure out if we are the only EC holding a read lock,
        # in which case we can acquire a write lock.
        @exclusive_count = Concurrent::LockLocalVar.new(0)
      end

      # The number of threads holding a read lock.
      attr :read_count

      # The number of threads holding a write lock.
      attr :write_count

      # Atomically increments the read count. If a write lock is held, this
      # will block until the write lock is released.
      def acquire_read_lock
        @guard.synchronize do
          while @write_count > 0
            @condition.wait(@guard)
          end

          @read_count += 1
          @exclusive_count.value += 1
        end
      end

      # Atomically decrements the read count. If the read count reaches zero,
      # any threads waiting on a write lock will be woken up.
      def release_read_lock
        @guard.synchronize do
          if @exclusive_count.value.zero?
            raise "Attempted to release a read lock when none were held."
          end

          @read_count -= 1
          @exclusive_count.value -= 1
        end

        @condition.broadcast
      end

      # Atomically increments and decrements the write count, yielding in
      # between. If a read lock is held, this will block until the lock is
      # released. However, the write lock will take priority.
      def with_write_lock
        @guard.synchronize do
          @write_count += 1

          while @read_count > @exclusive_count.value || @write_count > 1
            @condition.wait(@guard)
          end

          yield
        ensure
          @write_count -= 1
        end

        @condition.broadcast
      end
    end

    class Executor
      def initialize(watcher:)
        @execution_lock = ExecutionLock.new
        @cache_expiry = ViewModificationWatcher.new(watcher: watcher) do
          clear_cache
        end
      end

      def run
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          @cache_expiry.execute_if_updated
          @execution_lock.acquire_read_lock
        end
      end

      def complete(_)
        @execution_lock.release_read_lock
      end

      private
        def clear_cache
          @execution_lock.with_write_lock do
            ActionView::LookupContext::DetailsKey.clear
          end
        end
    end

    class ViewModificationWatcher
      def initialize(watcher:, &block)
        @watched_dirs = nil
        @watcher_class = watcher
        @watcher = nil
        @mutex = Mutex.new
        @block = block
      end

      def execute_if_updated
        @mutex.synchronize do
          watched_dirs = dirs_to_watch
          return if watched_dirs.empty?

          if watched_dirs != @watched_dirs
            @watched_dirs = watched_dirs
            @watcher = @watcher_class.new([], watched_dirs, &@block)
            @watcher.execute
          else
            @watcher.execute_if_updated
          end
        end
      end

      private
        def dirs_to_watch
          all_view_paths.grep(FileSystemResolver).map!(&:path).tap(&:uniq!).sort!
        end

        def all_view_paths
          ActionView::ViewPaths.all_view_paths.flat_map(&:paths)
        end
    end
  end
end
