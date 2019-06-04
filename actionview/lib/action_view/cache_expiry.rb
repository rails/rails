# frozen_string_literal: true

module ActionView
  class CacheExpiry
    class Executor
      def initialize(watcher:)
        @cache_expiry = CacheExpiry.new(watcher: watcher)
      end

      def before(target)
        @cache_expiry.clear_cache_if_necessary
      end
    end

    def initialize(watcher:)
      @watched_dirs = nil
      @watcher_class = watcher
      @watcher = nil
      @mutex = Mutex.new
    end

    def clear_cache_if_necessary
      @mutex.synchronize do
        watched_dirs = dirs_to_watch
        return if watched_dirs.empty?

        if watched_dirs != @watched_dirs
          @watched_dirs = watched_dirs
          @watcher = @watcher_class.new([], watched_dirs) do
            clear_cache
          end
          @watcher.execute
        else
          @watcher.execute_if_updated
        end
      end
    end

    def clear_cache
      ActionView::LookupContext::DetailsKey.clear
    end

    private

      def dirs_to_watch
        fs_paths = all_view_paths.grep(FileSystemResolver)
        fs_paths.map(&:path).sort.uniq
      end

      def all_view_paths
        ActionView::ViewPaths.all_view_paths.flat_map(&:paths)
      end
  end
end
