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
        @load_state = nil # nil (not loaded yet) | :loading | :loaded
        @load_lock = Monitor.new
        @file_watcher = file_watcher
      end

      def reload!
        @load_lock.synchronize do
          previous_state, @load_state = @load_state, :loading
          clear!
          load_paths
          finalize!
          route_sets.each(&:eager_load!) if eager_load
        ensure
          @load_state = previous_state
          revert
        end
      end

      def execute
        updater.execute
      end

      def execute_unless_loaded
        return false if @load_state == :loaded

        @load_lock.synchronize do
          # Another thread finished the load while this one was blocked on
          # @load_lock. Return true so callers like
          # LazyRouteSet#method_missing retry the url helper that was
          # missing when they were called.
          return true if @load_state == :loaded

          # Drawing the routes re-enters this method on the same thread —
          # config/routes.rb itself calls routes.draw — through the
          # reentrant Monitor; without this check the nested call would
          # recurse into another draw.
          return false if @load_state == :loading

          execute
          ActiveSupport.run_load_hooks(:after_routes_loaded, Rails.application)
          @load_state = :loaded
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
