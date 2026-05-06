# frozen_string_literal: true

module ActionView
  module CacheExpiry # :nodoc: all
    class ViewReloader
      def self.create(watcher:, &block)
        reloader = new(watcher: watcher, &block)
        ActionView::PathRegistry.file_system_resolver_hooks << reloader.hook
        reloader
      end

      def initialize(watcher:, &block)
        @mutex = Mutex.new
        @watcher_class = watcher
        @watched_dirs = nil
        @watcher = nil
        @previous_change = false
        @hook = method(:rebuild_watcher)
      end

      def updated?
        build_watcher unless @watcher
        @previous_change || @watcher&.updated?
      end

      def execute
        return unless @watcher

        watcher = nil
        @mutex.synchronize do
          @previous_change = false
          watcher = @watcher
        end
        watcher.execute
      end

      def rebuild_watcher
        return unless @watcher
        build_watcher
      end

      # Remove this reloader's hook from PathRegistry so forked processes that
      # clear reloaders stop triggering filesystem scans on prepend_view_path.
      def deactivate
        ActionView::PathRegistry.file_system_resolver_hooks.delete(@hook)
        @watcher = nil
        @watched_dirs = nil
      end

      # The bound method reference for rebuild_watcher.
      attr_reader :hook

      private
        def reload!
          ActionView::LookupContext::DetailsKey.clear
        end

        def build_watcher
          @mutex.synchronize do
            new_dirs = dirs_to_watch

            # Skip the build entirely if there are no view paths to watch and we have not built a watcher yet.
            return if new_dirs.empty? && @watcher.nil?

            old_watcher = @watcher

            if @watched_dirs != new_dirs
              @watched_dirs = new_dirs
              new_watcher = @watcher_class.new([], @watched_dirs) do
                reload!
              end
              @watcher = new_watcher

              # We must check the old watcher after initializing the new one to
              # ensure we don't miss any events
              @previous_change ||= old_watcher&.updated?
            end
          end
        end

        def dirs_to_watch
          all_view_paths.uniq.sort
        end

        def all_view_paths
          ActionView::PathRegistry.all_file_system_resolvers.map(&:path)
        end
    end
  end
end
