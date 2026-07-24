# frozen_string_literal: true

require "monitor"

module Rails
  class Application
    class RoutesReloader
      include ActiveSupport::Callbacks

      attr_reader :route_sets, :paths, :external_routes
      attr_accessor :eager_load
      attr_writer :run_once_after_load_paths # :nodoc:
      delegate :execute_if_updated, :updated?, to: :updater

      def initialize(file_watcher: ActiveSupport::FileUpdateChecker)
        @paths      = []
        @route_sets = []
        @external_routes = []
        @eager_load = false
        @loading = false
        @load_completed = false
        @load_lock = Monitor.new
        @file_watcher = file_watcher
      end

      def reload!
        @load_lock.synchronize do
          @loading = true
          clear!
          load_paths
          finalize!
          route_sets.each(&:eager_load!) if eager_load
        ensure
          @loading = false
          revert
        end
      end

      def execute
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

          # Drawing the routes re-enters this method on the same thread
          # (through the reentrant Monitor): config/routes.rb calls
          # routes.draw and may use url helpers. @loading turns those
          # nested calls into no-ops instead of recursive draws.
          return false if @loading

          execute
          ActiveSupport.run_load_hooks(:after_routes_loaded, Rails.application)
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
