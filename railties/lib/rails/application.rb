require 'fileutils'

module Rails
  class Application < Engine
    autoload :RoutesReloader, 'rails/application/routes_reloader'

    # TODO Check helpers works as expected
    # TODO Check routes namespaces
    class << self
      private :new
      alias   :configure :class_eval

      def instance
        @instance ||= new
      end

      def config
        @config ||= Configuration.new(self.original_root)
      end

      def original_root
        @original_root ||= find_root_with_file_flag("config.ru", Dir.pwd)
      end

      def inherited(base)
        super
        Railtie.plugins.delete(base)
        Rails.application = base.instance
      end

    protected

      def method_missing(*args, &block)
        instance.send(*args, &block)
      end
    end

    def initialize
      require_environment
    end

    def routes
      ActionController::Routing::Routes
    end

    def routes_reloader
      @routes_reloader ||= RoutesReloader.new(config)
    end

    def reload_routes!
      routes_reloader.reload!
    end

    def initialize!
      run_initializers(self)
      self
    end

    def require_environment
      environment = config.paths.config.environment.to_a.first
      require environment if environment
    end

    def load_tasks
      require "rails/tasks"
      plugins.each { |p| p.load_tasks }
      # Load all application tasks
      # TODO: extract out the path to the rake tasks
      Dir["#{root}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
      task :environment do
        $rails_rake_task = true
        initialize!
      end
    end

    def load_generators
      plugins.each { |p| p.load_generators }
    end

    # TODO: Fix this method. It loads all railties independent if :all is given
    # or not, otherwise frameworks are never loaded.
    def plugins
      @plugins ||= begin
        plugin_names = (config.plugins || [:all]).map { |p| p.to_sym }
        Railtie.plugins.map(&:new) + Plugin.all(plugin_names, config.paths.vendor.plugins)
      end
    end

    def app
      @app ||= middleware.build(routes)
    end

    def call(env)
      env["action_dispatch.parameter_filter"] = config.filter_parameters
      app.call(env)
    end

    def initializers
      initializers = Bootstrap.initializers
      initializers += super
      plugins.each { |p| initializers += p.initializers }
      initializers += Finisher.initializers
      initializers
    end

    module Bootstrap
      include Initializable

      initializer :load_all_active_support do |app|
        require "active_support/all" unless app.config.active_support.bare
      end

      # Preload all frameworks specified by the Configuration#frameworks.
      # Used by Passenger to ensure everything's loaded before forking and
      # to avoid autoload race conditions in JRuby.
      initializer :preload_frameworks do |app|
        require 'active_support/dependencies'
        ActiveSupport::Autoload.eager_autoload! if app.config.preload_frameworks
      end

      # Initialize the logger early in the stack in case we need to log some deprecation.
      initializer :initialize_logger do |app|
        Rails.logger ||= app.config.logger || begin
          path = app.config.paths.log.to_a.first
          logger = ActiveSupport::BufferedLogger.new(path)
          logger.level = ActiveSupport::BufferedLogger.const_get(app.config.log_level.to_s.upcase)
          logger.auto_flushing = false if Rails.env.production?
          logger
        rescue StandardError => e
          logger = ActiveSupport::BufferedLogger.new(STDERR)
          logger.level = ActiveSupport::BufferedLogger::WARN
          logger.warn(
            "Rails Error: Unable to access log file. Please ensure that #{path} exists and is chmod 0666. " +
            "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
          )
          logger
        end
      end

      # Initialize cache early in the stack so railties can make use of it.
      initializer :initialize_cache do |app|
        unless defined?(RAILS_CACHE)
          silence_warnings { Object.const_set "RAILS_CACHE", ActiveSupport::Cache.lookup_store(app.config.cache_store) }

          if RAILS_CACHE.respond_to?(:middleware)
            app.config.middleware.insert_after(:"Rack::Lock", RAILS_CACHE.middleware)
          end
        end
      end

      # Initialize rails subscriber on top of notifications.
      initializer :initialize_subscriber do |app|
        require 'active_support/notifications'

        if app.config.colorize_logging == false
          Rails::Subscriber.colorize_logging     = false
          app.config.generators.colorize_logging = false
        end

        ActiveSupport::Notifications.subscribe do |*args|
          Rails::Subscriber.dispatch(args)
        end
      end

      initializer :set_clear_dependencies_hook do |app|
        unless app.config.cache_classes
          ActionDispatch::Callbacks.after do
            ActiveSupport::Dependencies.clear
          end
        end
      end

      # Sets the dependency loading mechanism.
      # TODO: Remove files from the $" and always use require.
      initializer :initialize_dependency_mechanism do |app|
        ActiveSupport::Dependencies.mechanism = app.config.cache_classes ? :require : :load
      end
    end

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
