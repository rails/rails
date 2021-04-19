# frozen_string_literal: true

module ActionView
  class CacheExpiry
    class Executor
      def initialize(watcher:)
        @execution_lock = Concurrent::ReadWriteLock.new
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
