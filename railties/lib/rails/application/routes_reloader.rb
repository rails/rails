# frozen_string_literal: true

require "monitor"

module Rails
  class Application
    class RoutesReloader
      include ActiveSupport::Callbacks

      attr_reader :route_sets, :paths, :external_routes, :loaded
      attr_accessor :eager_load
      attr_writer :run_once_after_load_paths # :nodoc:
      delegate :execute_if_updated, :updated?, to: :updater

      def initialize(file_watcher: ActiveSupport::FileUpdateChecker)
        @paths      = []
        @route_sets = []
        @external_routes = []
        @eager_load = false
        @loaded = false
        @load_completed = false
        @load_lock = Monitor.new
        @file_watcher = file_watcher
      end

      def reload!
        clear!
        load_paths
        finalize!
        route_sets.each(&:eager_load!) if eager_load
      ensure
        revert
      end

      # Kept in sync with the fast path in #execute_unless_loaded: assigning
      # false makes the next lazy loading trigger draw the routes again.
      def loaded=(loaded) # :nodoc:
        @load_lock.synchronize do
          @loaded = loaded
          @load_completed = loaded
        end
      end

      def execute
        @loaded = true
        updater.execute
      end

      def execute_unless_loaded
        return false if @load_completed

        @load_lock.synchronize do
          # The draw happened on another thread while this one was blocked
          # on @load_lock. Callers like LazyRouteSet#method_missing treat a
          # truthy return as "the routes just got loaded, retry": url
          # helpers that were missing when this thread called them are
          # defined now.
          return true if @load_completed

          # @loaded is set before drawing so that lazy loading triggers hit
          # while drawing the routes (e.g. url helpers used in config/routes.rb)
          # re-enter the Monitor and return here instead of recursing into
          # another draw. Being true mid-draw, it can't serve as the lock-free
          # fast path — that is @load_completed, set only once the draw is done.
          return false if @loaded

          begin
            execute
            ActiveSupport.run_load_hooks(:after_routes_loaded, Rails.application)
          rescue Exception
            # Roll back so that waiting threads and subsequent requests retry
            # the draw and surface its error, rather than dispatching against
            # a half-drawn route set.
            @loaded = false
            raise
          end

          @load_completed = true
          true
        end
      end

    private
      def updater
        @updater ||= begin
          dirs = @external_routes.each_with_object({}) do |dir, hash|
            hash[dir.to_s] = %w(rb)
          end

          @file_watcher.new(paths, dirs) { reload! }
        end
      end

      def clear!
        route_sets.each do |routes|
          routes.disable_clear_and_finalize = true
          routes.clear!
        end
      end

      def load_paths
        paths.each { |path| load(path) }
        run_after_load_paths_callback
      end

      def run_after_load_paths_callback
        if @run_once_after_load_paths
          @run_once_after_load_paths.call
          @run_once_after_load_paths = nil
        end
      end

      def finalize!
        route_sets.each(&:finalize!)
      end

      def revert
        route_sets.each do |routes|
          routes.disable_clear_and_finalize = false
        end
      end
    end
  end
end
