module Rails
  class Application
    class RoutesReloader
      # TODO Change config.action_dispatch.route_files to config.action_dispatch.routes_path
      # TODO Write tests
      def initialize(config)
        @config, @last_change_at = config, nil
      end

      def changed_at
        routes_changed_at = nil

        files.each do |file|
          config_changed_at = File.stat(file).mtime

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
        files.each { |file| load(file) }
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

      def files
        @config.action_dispatch.route_files
      end
    end
  end
end