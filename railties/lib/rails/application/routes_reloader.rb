# frozen_string_literal: true


module Rails
  class Application
    class RoutesReloader
      include ActiveSupport::Callbacks

      attr_reader :route_sets, :paths, :external_routes, :loaded
      attr_accessor :eager_load
      attr_writer :run_after_load_paths, :loaded # :nodoc:
      delegate :execute_if_updated, :updated?, to: :updater

      def initialize
        @paths      = []
        @route_sets = []
        @external_routes = []
        @eager_load = false
        @loaded = false
      end

      def reload!
        clear!
        load_paths
        finalize!
        route_sets.each(&:eager_load!) if eager_load
      ensure
        revert
      end

      def execute
        @loaded = true
        updater.execute
      end

      def execute_unless_loaded
        unless @loaded
          execute
          ActiveSupport.run_load_hooks(:after_routes_loaded, Rails.application)
          true
        end
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
        @run_after_load_paths ||= -> { }
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
