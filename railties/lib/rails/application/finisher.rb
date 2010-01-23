module Rails
  class Application
    module Finisher
      include Initializable

      initializer :add_builtin_route do |app|
        if Rails.env.development?
          app.config.action_dispatch.route_files << File.join(RAILTIES_PATH, 'builtin', 'routes.rb')
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