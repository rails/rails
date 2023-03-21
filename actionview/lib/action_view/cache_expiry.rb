# frozen_string_literal: true

module ActionView
  module CacheExpiry # :nodoc: all
    class ViewReloader
      def initialize(watcher:, &block)
        @mutex = Mutex.new
        @watcher_class = watcher
        @watched_dirs = nil
        @watcher = nil
        @previous_change = false

        rebuild_watcher

        ActionView::PathRegistry.file_system_resolver_hooks << method(:rebuild_watcher)
      end

      def updated?
        @previous_change || @watcher.updated?
      end

      def execute
        watcher = nil
        @mutex.synchronize do
          @previous_change = false
          watcher = @watcher
        end
        watcher.execute
      end

      private
        def reload!
          ActionView::LookupContext::DetailsKey.clear
        end

        def rebuild_watcher
          @mutex.synchronize do
            old_watcher = @watcher

            if @watched_dirs != dirs_to_watch
              @watched_dirs = dirs_to_watch
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
