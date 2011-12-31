require "active_support/core_ext/module/delegation"

module Rails
  class Application
    class RoutesReloader
      attr_reader :route_sets, :paths
      delegate :execute_if_updated, :execute, :updated?, :to => :updater

      def initialize
        @paths      = []
        @route_sets = []
      end

      def reload!
        clear!
        load_paths
        finalize!
      ensure
        revert
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
        route_sets.each do |routes|
          ActiveSupport.on_load(:action_controller) { routes.finalize! }
        end
      end

      def revert
        route_sets.each do |routes|
          routes.disable_clear_and_finalize = false
        end
      end
    end
  end
end
