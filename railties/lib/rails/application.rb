require "fileutils"
require 'active_support/core_ext/module/delegation'

module Rails
  class Application
    include Initializable

    class << self
      attr_writer :config
      alias configure class_eval
      delegate :initialize!, :load_tasks, :root, :to => :instance

      private :new
      def instance
        @instance ||= new
      end

      def config
        @config ||= Configuration.new(Plugin::Configuration.default)
      end

      def routes
        ActionController::Routing::Routes
      end
    end

    delegate :config, :routes, :to => :'self.class'
    delegate :root, :middleware, :to => :config
    attr_reader :route_configuration_files

    def initialize
      require_environment
      Rails.application ||= self
      @route_configuration_files = []
    end

    def initialize!
      run_initializers(self)
      self
    end

    def require_environment
      require config.environment_path
    rescue LoadError
    end

    def routes_changed_at
      routes_changed_at = nil

      route_configuration_files.each do |config|
        config_changed_at = File.stat(config).mtime

        if routes_changed_at.nil? || config_changed_at > routes_changed_at
          routes_changed_at = config_changed_at
        end
      end

      routes_changed_at
    end

    def reload_routes!
      routes.disable_clear_and_finalize = true

      routes.clear!
      route_configuration_files.each { |config| load(config) }
      routes.finalize!

      nil
    ensure
      routes.disable_clear_and_finalize = false
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

    def initializers
      initializers = super
      plugins.each { |p| initializers += p.initializers }
      initializers
    end

    # TODO: Fix this method
    def plugins
      @plugins ||= begin
        plugin_names = config.plugins || [:all]
        Railtie.plugins.select { |p| plugin_names.include?(:all) || plugin_names.include?(p.plugin_name) }.map { |p| p.new } +
        Plugin.all(config.plugins || [:all], config.paths.vendor.plugins)
      end
    end

    def call(env)
      @app ||= middleware.build(routes)
      @app.call(env)
    end

    initializer :load_all_active_support do
      require "active_support/all" unless config.active_support.bare
    end

    # Set the <tt>$LOAD_PATH</tt> based on the value of
    # Configuration#load_paths. Duplicates are removed.
    initializer :set_load_path do
      config.paths.add_to_load_path
      $LOAD_PATH.uniq!
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

    # Create tmp directories
    initializer :ensure_tmp_directories_exist do
      %w(cache pids sessions sockets).each do |dir_to_make|
        FileUtils.mkdir_p(File.join(root, 'tmp', dir_to_make))
      end
    end

    # Preload all frameworks specified by the Configuration#frameworks.
    # Used by Passenger to ensure everything's loaded before forking and
    # to avoid autoload race conditions in JRuby.
    initializer :preload_frameworks do
      ActiveSupport::Autoload.eager_autoload! if config.preload_frameworks
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

    # Sets the default value for Time.zone
    # If assigned value cannot be matched to a TimeZone, an exception will be raised.
    initializer :initialize_time_zone do
      if config.time_zone
        require 'active_support/core_ext/time/zones'
        zone_default = Time.__send__(:get_zone, config.time_zone)

        unless zone_default
          raise \
            'Value assigned to config.time_zone not recognized.' +
            'Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
        end

        Time.zone_default = zone_default
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

    # # bail out if gems are missing - note that check_gem_dependencies will have
    # # already called abort() unless $gems_rake_task is set
    # return unless gems_dependencies_loaded
    initializer :load_application_initializers do
      Dir["#{root}/config/initializers/**/*.rb"].sort.each do |initializer|
        load(initializer)
      end
    end

    # Fires the user-supplied after_initialize block (Configuration#after_initialize)
    initializer :after_initialize do
      config.after_initialize_blocks.each do |block|
        block.call
      end
    end

    # Eager load application classes
    initializer :load_application_classes do
      next if $rails_rake_task

      if config.cache_classes
        config.eager_load_paths.each do |load_path|
          matcher = /\A#{Regexp.escape(load_path)}(.*)\.rb\Z/
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1')
          end
        end
      end
    end

    # Disable dependency loading during request cycle
    initializer :disable_dependency_loading do
      if config.cache_classes && !config.dependency_loading
        ActiveSupport::Dependencies.unhook!
      end
    end
  end
end
