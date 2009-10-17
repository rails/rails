module Rails
  class Application
    extend Initializable

    class << self
      # Stub out App initialize
      def initialize!
        new
      end

      def config
        @config ||= Configuration.new
      end

      # TODO: change the plugin loader to use config
      alias configuration config

      def config=(config)
        @config = config
      end

      def plugin_loader
        @plugin_loader ||= config.plugin_loader.new(self)
      end

      def root
        config.root
      end

      def routes
        ActionController::Routing::Routes
      end

      def middleware
        config.middleware
      end

      def call(env)
        @app ||= middleware.build(routes)
        @app.call(env)
      end

      def new
        initializers.run
        self
      end
    end

    initializer :initialize_rails do
      Rails.initializers.run
    end

    # Set the <tt>$LOAD_PATH</tt> based on the value of
    # Configuration#load_paths. Duplicates are removed.
    initializer :set_load_path do
      config.paths.add_to_load_path
      $LOAD_PATH.uniq!
    end

    # Requires all frameworks specified by the Configuration#frameworks
    # list. By default, all frameworks (Active Record, Active Support,
    # Action Pack, Action Mailer, and Active Resource) are loaded.
    initializer :require_frameworks do
      begin
        require 'active_support'
        require 'active_support/core_ext/kernel/reporting'
        require 'active_support/core_ext/logger'

        # TODO: This is here to make Sam Ruby's tests pass. Needs discussion.
        require 'active_support/core_ext/numeric/bytes'
        config.frameworks.each { |framework| require(framework.to_s) }
      rescue LoadError => e
        # Re-raise as RuntimeError because Mongrel would swallow LoadError.
        raise e.to_s
      end
    end

    # Set the paths from which Rails will automatically load source files, and
    # the load_once paths.
    initializer :set_autoload_paths do
      require 'active_support/dependencies'
      ActiveSupport::Dependencies.load_paths = config.load_paths.uniq
      ActiveSupport::Dependencies.load_once_paths = config.load_once_paths.uniq

      extra = ActiveSupport::Dependencies.load_once_paths - ActiveSupport::Dependencies.load_paths
      unless extra.empty?
        abort <<-end_error
          load_once_paths must be a subset of the load_paths.
          Extra items in load_once_paths: #{extra * ','}
        end_error
      end

      # Freeze the arrays so future modifications will fail rather than do nothing mysteriously
      config.load_once_paths.freeze
    end

    # Adds all load paths from plugins to the global set of load paths, so that
    # code from plugins can be required (explicitly or automatically via ActiveSupport::Dependencies).
    initializer :add_plugin_load_paths do
      require 'active_support/dependencies'
      plugin_loader.add_plugin_load_paths
    end

    # Create tmp directories
    initializer :ensure_tmp_directories_exist do
      %w(cache pids sessions sockets).each do |dir_to_make|
        FileUtils.mkdir_p(File.join(config.root, 'tmp', dir_to_make))
      end
    end

    # Loads the environment specified by Configuration#environment_path, which
    # is typically one of development, test, or production.
    initializer :load_environment do
      silence_warnings do
        next if @environment_loaded
        next unless File.file?(config.environment_path)

        @environment_loaded = true
        constants = self.class.constants

        eval(IO.read(config.environment_path), binding, config.environment_path)

        (self.class.constants - constants).each do |const|
          Object.const_set(const, self.class.const_get(const))
        end
      end
    end

    # Preload all frameworks specified by the Configuration#frameworks.
    # Used by Passenger to ensure everything's loaded before forking and
    # to avoid autoload race conditions in JRuby.
    initializer :preload_frameworks do
      if config.preload_frameworks
        config.frameworks.each do |framework|
          # String#classify and #constantize aren't available yet.
          toplevel = Object.const_get(framework.to_s.gsub(/(?:^|_)(.)/) { $1.upcase })
          toplevel.load_all! if toplevel.respond_to?(:load_all!)
        end
      end
    end

    # This initialization routine does nothing unless <tt>:active_record</tt>
    # is one of the frameworks to load (Configuration#frameworks). If it is,
    # this sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    initializer :initialize_database do
      if config.frameworks.include?(:active_record)
        ActiveRecord::Base.configurations = config.database_configuration
        ActiveRecord::Base.establish_connection
      end
    end

    # Include middleware to serve up static assets
    initializer :initialize_static_server do
      if config.frameworks.include?(:action_controller) && config.serve_static_assets
        config.middleware.use(ActionDispatch::Static, Rails.public_path)
      end
    end

    initializer :initialize_middleware_stack do
      if config.frameworks.include?(:action_controller)
        config.middleware.use(::Rack::Lock) unless ActionController::Base.allow_concurrency
        config.middleware.use(ActionDispatch::ShowExceptions, ActionController::Base.consider_all_requests_local)
        config.middleware.use(ActionDispatch::Callbacks, ActionController::Dispatcher.prepare_each_request)
        config.middleware.use(lambda { ActionController::Base.session_store }, lambda { ActionController::Base.session_options })
        config.middleware.use(ActionDispatch::ParamsParser)
        config.middleware.use(::Rack::MethodOverride)
        config.middleware.use(::Rack::Head)
        config.middleware.use(ActionDispatch::StringCoercion)
      end
    end

    initializer :initialize_cache do
      unless defined?(RAILS_CACHE)
        silence_warnings { Object.const_set "RAILS_CACHE", ActiveSupport::Cache.lookup_store(config.cache_store) }

        if RAILS_CACHE.respond_to?(:middleware)
          # Insert middleware to setup and teardown local cache for each request
          config.middleware.insert_after(:"Rack::Lock", RAILS_CACHE.middleware)
        end
      end
    end

    initializer :initialize_framework_caches do
      if config.frameworks.include?(:action_controller)
        ActionController::Base.cache_store ||= RAILS_CACHE
      end
    end

    initializer :initialize_logger do
      # if the environment has explicitly defined a logger, use it
      next if Rails.logger

      unless logger = config.logger
        begin
          logger = ActiveSupport::BufferedLogger.new(config.log_path)
          logger.level = ActiveSupport::BufferedLogger.const_get(config.log_level.to_s.upcase)
          if RAILS_ENV == "production"
            logger.auto_flushing = false
          end
        rescue StandardError => e
          logger = ActiveSupport::BufferedLogger.new(STDERR)
          logger.level = ActiveSupport::BufferedLogger::WARN
          logger.warn(
            "Rails Error: Unable to access log file. Please ensure that #{config.log_path} exists and is chmod 0666. " +
            "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
          )
        end
      end

      # TODO: Why are we silencing warning here?
      silence_warnings { Object.const_set "RAILS_DEFAULT_LOGGER", logger }
    end

    # Sets the logger for Active Record, Action Controller, and Action Mailer
    # (but only for those frameworks that are to be loaded). If the framework's
    # logger is already set, it is not changed, otherwise it is set to use
    # RAILS_DEFAULT_LOGGER.
    initializer :initialize_framework_logging do
      for framework in ([ :active_record, :action_controller, :action_mailer ] & config.frameworks)
        framework.to_s.camelize.constantize.const_get("Base").logger ||= Rails.logger
      end

      ActiveSupport::Dependencies.logger ||= Rails.logger
      Rails.cache.logger ||= Rails.logger
    end

    # Sets the dependency loading mechanism based on the value of
    # Configuration#cache_classes.
    initializer :initialize_dependency_mechanism do
      # TODO: Remove files from the $" and always use require
      ActiveSupport::Dependencies.mechanism = config.cache_classes ? :require : :load
    end

    # Loads support for "whiny nil" (noisy warnings when methods are invoked
    # on +nil+ values) if Configuration#whiny_nils is true.
    initializer :initialize_whiny_nils do
      require('active_support/whiny_nil') if config.whiny_nils
    end

    # Sets the default value for Time.zone, and turns on ActiveRecord::Base#time_zone_aware_attributes.
    # If assigned value cannot be matched to a TimeZone, an exception will be raised.
    initializer :initialize_time_zone do
      if config.time_zone
        zone_default = Time.__send__(:get_zone, config.time_zone)

        unless zone_default
          raise \
            'Value assigned to config.time_zone not recognized.' +
            'Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
        end

        Time.zone_default = zone_default

        if config.frameworks.include?(:active_record)
          ActiveRecord::Base.time_zone_aware_attributes = true
          ActiveRecord::Base.default_timezone = :utc
        end
      end
    end

    # Set the i18n configuration from config.i18n but special-case for the load_path which should be
    # appended to what's already set instead of overwritten.
    initializer :initialize_i18n do
      config.i18n.each do |setting, value|
        if setting == :load_path
          I18n.load_path += value
        else
          I18n.send("#{setting}=", value)
        end
      end
    end

    # Initializes framework-specific settings for each of the loaded frameworks
    # (Configuration#frameworks). The available settings map to the accessors
    # on each of the corresponding Base classes.
    initializer :initialize_framework_settings do
      config.frameworks.each do |framework|
        base_class = framework.to_s.camelize.constantize.const_get("Base")

        config.send(framework).each do |setting, value|
          base_class.send("#{setting}=", value)
        end
      end
      config.active_support.each do |setting, value|
        ActiveSupport.send("#{setting}=", value)
      end
    end

    # Sets +ActionController::Base#view_paths+ and +ActionMailer::Base#template_root+
    # (but only for those frameworks that are to be loaded). If the framework's
    # paths have already been set, it is not changed, otherwise it is
    # set to use Configuration#view_path.
    initializer :initialize_framework_views do
      if config.frameworks.include?(:action_view)
        view_path = ActionView::PathSet.type_cast(config.view_path, config.cache_classes)
        ActionMailer::Base.template_root  = view_path if config.frameworks.include?(:action_mailer) && ActionMailer::Base.view_paths.blank?
        ActionController::Base.view_paths = view_path if config.frameworks.include?(:action_controller) && ActionController::Base.view_paths.blank?
      end
    end

    initializer :initialize_metal do
      # TODO: Make Rails and metal work without ActionController
      if config.frameworks.include?(:action_controller)
        Rails::Rack::Metal.requested_metals = config.metals
        Rails::Rack::Metal.metal_paths += plugin_loader.engine_metal_paths

        config.middleware.insert_before(
          :"ActionDispatch::ParamsParser",
          Rails::Rack::Metal, :if => Rails::Rack::Metal.metals.any?)
      end
    end

    # Loads all plugins in <tt>config.plugin_paths</tt>.  <tt>plugin_paths</tt>
    # defaults to <tt>vendor/plugins</tt> but may also be set to a list of
    # paths, such as
    #   config.plugin_paths = ["#{config.root}/lib/plugins", "#{config.root}/vendor/plugins"]
    #
    # In the default implementation, as each plugin discovered in <tt>plugin_paths</tt> is initialized:
    # * its +lib+ directory, if present, is added to the load path (immediately after the applications lib directory)
    # * <tt>init.rb</tt> is evaluated, if present
    #
    # After all plugins are loaded, duplicates are removed from the load path.
    # If an array of plugin names is specified in config.plugins, only those plugins will be loaded
    # and they plugins will be loaded in that order. Otherwise, plugins are loaded in alphabetical
    # order.
    #
    # if config.plugins ends contains :all then the named plugins will be loaded in the given order and all other
    # plugins will be loaded in alphabetical order
    initializer :load_plugins do
      plugin_loader.load_plugins
    end

    # # bail out if gems are missing - note that check_gem_dependencies will have
    # # already called abort() unless $gems_rake_task is set
    # return unless gems_dependencies_loaded
    initializer :load_application_initializers do
      Dir["#{configuration.root}/config/initializers/**/*.rb"].sort.each do |initializer|
        load(initializer)
      end
    end

    # Fires the user-supplied after_initialize block (Configuration#after_initialize)
    initializer :after_initialize do
      configuration.after_initialize_blocks.each do |block|
        block.call
      end
    end

    # # Setup database middleware after initializers have run
    initializer :initialize_database_middleware do
      if configuration.frameworks.include?(:active_record)
        if configuration.frameworks.include?(:action_controller) && ActionController::Base.session_store &&
            ActionController::Base.session_store.name == 'ActiveRecord::SessionStore'
          configuration.middleware.insert_before :"ActiveRecord::SessionStore", ActiveRecord::ConnectionAdapters::ConnectionManagement
          configuration.middleware.insert_before :"ActiveRecord::SessionStore", ActiveRecord::QueryCache
        else
          configuration.middleware.use ActiveRecord::ConnectionAdapters::ConnectionManagement
          configuration.middleware.use ActiveRecord::QueryCache
        end
      end
    end

    # TODO: Make a DSL way to limit an initializer to a particular framework

    # # Prepare dispatcher callbacks and run 'prepare' callbacks
    initializer :prepare_dispatcher do
      next unless configuration.frameworks.include?(:action_controller)
      require 'rails/dispatcher' unless defined?(::Dispatcher)
      Dispatcher.define_dispatcher_callbacks(configuration.cache_classes)
    end

    # Routing must be initialized after plugins to allow the former to extend the routes
    # ---
    # If Action Controller is not one of the loaded frameworks (Configuration#frameworks)
    # this does nothing. Otherwise, it loads the routing definitions and sets up
    # loading module used to lazily load controllers (Configuration#controller_paths).
    initializer :initialize_routing do
      next unless configuration.frameworks.include?(:action_controller)

      ActionController::Routing.controller_paths += configuration.controller_paths
      ActionController::Routing::Routes.add_configuration_file(configuration.routes_configuration_file)
      ActionController::Routing::Routes.reload!
    end
    #
    # # Observers are loaded after plugins in case Observers or observed models are modified by plugins.
    initializer :load_observers do
      if configuration.frameworks.include?(:active_record)
        ActiveRecord::Base.instantiate_observers
      end
    end

    # Eager load application classes
    initializer :load_application_classes do
      next if $rails_rake_task

      if configuration.cache_classes
        configuration.eager_load_paths.each do |load_path|
          matcher = /\A#{Regexp.escape(load_path)}(.*)\.rb\Z/
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1')
          end
        end
      end
    end

    # Disable dependency loading during request cycle
    initializer :disable_dependency_loading do
      if configuration.cache_classes && !configuration.dependency_loading
        ActiveSupport::Dependencies.unhook!
      end
    end

    # Configure generators if they were already loaded
    # ===
    # TODO: Does this need to be an initializer here?
    initializer :initialize_generators do
      if defined?(Rails::Generators)
        Rails::Generators.no_color! unless config.generators.colorize_logging
        Rails::Generators.aliases.deep_merge! config.generators.aliases
        Rails::Generators.options.deep_merge! config.generators.options
      end
    end

    # For each framework, search for instrument file with Notifications hooks.
    #
    initializer :load_notifications_hooks do
      config.frameworks.each do |framework|
        begin
          require "#{framework}/notifications"
        rescue LoadError => e
        end
      end
    end
  end
end
