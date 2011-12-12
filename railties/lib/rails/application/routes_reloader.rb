module Rails
  class Application
    class RoutesReloader
      attr_reader :route_sets

      def initialize(updater=ActiveSupport::FileUpdateChecker)
        @updater    = updater.new([]) { reload! }
        @route_sets = []
      end

      def paths
        @updater.paths
      end

      def execute_if_updated
        @updater.execute_if_updated
      end

      def reload!
        clear!
        load_paths
        finalize!
      ensure
        revert
      end

    protected

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
