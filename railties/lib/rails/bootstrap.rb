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

    initializer :initialize_logger do
      Rails.logger ||= config.logger || begin
        logger = ActiveSupport::BufferedLogger.new(config.paths.log.to_a.first)
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

    initializer :container do
      # FIXME This is just a dumb initializer used as hook
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

    # Sets the dependency loading mechanism based on the value of
    # Configuration#cache_classes.
    initializer :initialize_dependency_mechanism do
      # TODO: Remove files from the $" and always use require
      ActiveSupport::Dependencies.mechanism = config.cache_classes ? :require : :load
    end
  end
end
