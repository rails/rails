# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module Rails
  class Application
    class RoutesReloader
      include ActiveSupport::Callbacks

      attr_reader :route_sets, :paths, :external_routes
      attr_accessor :eager_load
      attr_writer :run_after_load_paths # :nodoc:
      delegate :execute_if_updated, :execute, :updated?, to: :updater

      def initialize
        @paths      = []
        @route_sets = []
        @external_routes = []
        @eager_load = false
      end

      def reload!
        clear!
        load_paths
        finalize!
        route_sets.each(&:eager_load!) if eager_load
      ensure
        revert
      end

    private
      def updater
        @updater ||= begin
          dirs = @external_routes.each_with_object({}) do |dir, hash|
            hash[dir.to_s] = %w(rb)
          end

          ActiveSupport::FileUpdateChecker.new(paths, dirs) { reload! }
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
        run_after_load_paths.call
      end

      def run_after_load_paths
        @run_after_load_paths ||= -> {}
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
