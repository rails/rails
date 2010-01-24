module Rails
  class Application
    # TODO Write tests for this behavior extracted from Application
    class RoutesReloader
      def self.paths
        @paths ||= []
      end

      def initialize(config)
        @config, @last_change_at = config, nil
      end

      def changed_at
        routes_changed_at = nil

        self.class.paths.each do |path|
          config_changed_at = File.stat(path).mtime

          if routes_changed_at.nil? || config_changed_at > routes_changed_at
            routes_changed_at = config_changed_at
          end
        end

        routes_changed_at
      end

      def reload!
        routes = Rails::Application.routes
        routes.disable_clear_and_finalize = true

        routes.clear!
        self.class.paths.each { |path| load(path) }
        routes.finalize!

        nil
      ensure
        routes.disable_clear_and_finalize = false
      end

      def reload_if_changed
        current_change_at = changed_at
        if @last_change_at != current_change_at
          @last_change_at = current_change_at
          reload!
        end
      end
    end
  end
end