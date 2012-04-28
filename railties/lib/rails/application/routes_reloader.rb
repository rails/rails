require "active_support/core_ext/module/delegation"

module Rails
  class Application
    class RoutesReloader
      attr_reader :route_sets, :paths, :external_routes
      delegate :execute_if_updated, :execute, :updated?, :to => :updater

      def initialize
        @paths           = []
        @route_sets      = []
        @external_routes = []
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
          dirs = @external_routes.inject({}) do |hash, dir|
            hash.merge(dir.to_s => ["rb"])
          end

          updater = ActiveSupport::FileUpdateChecker.new(paths, dirs) { reload! }

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
          routes.finalize!
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
