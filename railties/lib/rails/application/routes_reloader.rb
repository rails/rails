require "active_support/core_ext/module/delegation"

module Rails
  class Application
    class RoutesReloader
      attr_reader :route_sets, :paths
      attr_accessor :eager_load
      delegate :updated?, to: :updater

      def initialize
        @paths      = []
        @route_sets = []
        @eager_load = false
      end

      def reload!
        clear!
        load_paths
        finalize!
      ensure
        revert
      end

      def execute
        ret = updater.execute
        route_sets.each(&:eager_load!) if eager_load
        ret
      end

      def execute_if_updated
        if updated = updater.execute_if_updated
          route_sets.each(&:eager_load!) if eager_load
        end
        updated
      end

    private

      def updater
        @updater ||= begin
          updater = ActiveSupport::FileUpdateChecker.new(paths) { reload! }
          updater.execute
          updater
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
