module Rails
  class Application
    module Finisher
      include Initializable

      initializer :ensure_load_once_paths_as_subset do
        extra = ActiveSupport::Dependencies.load_once_paths -
                ActiveSupport::Dependencies.load_paths

        unless extra.empty?
          abort <<-end_error
            load_once_paths must be a subset of the load_paths.
            Extra items in load_once_paths: #{extra * ','}
          end_error
        end
      end

      initializer :add_builtin_route do |app|
        if Rails.env.development?
          Rails::Application::RoutesReloader.paths << File.join(RAILTIES_PATH, 'builtin', 'routes.rb')
        end
      end

      initializer :build_middleware_stack do |app|
        app.app
      end

      # Fires the user-supplied after_initialize block (config#after_initialize)
      initializer :after_initialize do |app|
        app.config.after_initialize_blocks.each do |block|
          block.call(app)
        end
      end

      # Disable dependency loading during request cycle
      initializer :disable_dependency_loading do |app|
        if app.config.cache_classes && !app.config.dependency_loading
          ActiveSupport::Dependencies.unhook!
        end
      end
    end
  end
end