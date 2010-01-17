module Rails
  class Bootstrap #< Railtie
    include Initializable

    def initialize(application)
      @application = application
    end

    delegate :config, :root, :to => :'@application'

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
      Rails.logger ||= config.logger || begin
        logger = ActiveSupport::BufferedLogger.new(config.log_path)
        logger.level = ActiveSupport::BufferedLogger.const_get(config.log_level.to_s.upcase)
        logger.auto_flushing = false if Rails.env.production?
        logger
      rescue StandardError => e
        logger = ActiveSupport::BufferedLogger.new(STDERR)
        logger.level = ActiveSupport::BufferedLogger::WARN
        logger.warn(
          "Rails Error: Unable to access log file. Please ensure that #{config.log_path} exists and is chmod 0666. " +
          "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
        )
        logger
      end
    end

    # Sets the logger for dependencies and cache store.
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
      require 'active_support/whiny_nil' if config.whiny_nils
    end

    # Sets the default value for Time.zone
    # If assigned value cannot be matched to a TimeZone, an exception will be raised.
    initializer :initialize_time_zone do
      require 'active_support/core_ext/time/zones'
      zone_default = Time.__send__(:get_zone, config.time_zone)

      unless zone_default
        raise \
          'Value assigned to config.time_zone not recognized.' +
          'Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
      end

      Time.zone_default = zone_default
    end

    # Set the i18n configuration from config.i18n but special-case for the load_path which should be
    # appended to what's already set instead of overwritten.
    initializer :initialize_i18n do
      require 'active_support/i18n'

      config.i18n.each do |setting, value|
        if setting == :load_path
          I18n.load_path += value
        else
          I18n.send("#{setting}=", value)
        end
      end

      ActionDispatch::Callbacks.to_prepare do
        I18n.reload!
      end
    end

    initializer :set_clear_dependencies_hook do
      unless config.cache_classes
        ActionDispatch::Callbacks.after do
          ActiveSupport::Dependencies.clear
        end
      end
    end

    initializer :initialize_notifications do 
      require 'active_support/notifications'

      if config.colorize_logging == false
        Rails::Subscriber.colorize_logging = false
        config.generators.colorize_logging = false
      end

      ActiveSupport::Notifications.subscribe do |*args|
        Rails::Subscriber.dispatch(args)
      end
    end
  end
end
