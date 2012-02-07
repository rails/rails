require "active_support/notifications"
require "active_support/dependencies"
require "active_support/descendants_tracker"

module Rails
  class Application
    module Bootstrap
      include Initializable

      initializer :load_environment_hook, :group => :all do end

      initializer :load_active_support, :group => :all do
        require "active_support/all" unless config.active_support.bare
      end

      # Preload all frameworks specified by the Configuration#frameworks.
      # Used by Passenger to ensure everything's loaded before forking and
      # to avoid autoload race conditions in JRuby.
      initializer :preload_frameworks, :group => :all do
        ActiveSupport::Autoload.eager_autoload! if config.preload_frameworks
      end

      # Initialize the logger early in the stack in case we need to log some deprecation.
      initializer :initialize_logger, :group => :all do
        Rails.logger ||= config.logger || begin
          path = config.paths["log"].first
          unless File.exist? File.dirname path
            FileUtils.mkdir_p File.dirname path
          end

          f = File.open path, 'a'
          f.binmode
          f.sync = true # make sure every write flushes

          logger = ActiveSupport::TaggedLogging.new(
            ActiveSupport::BufferedLogger.new(f)
          )
          logger.level = ActiveSupport::BufferedLogger.const_get(config.log_level.to_s.upcase)
          logger
        rescue StandardError
          logger = ActiveSupport::TaggedLogging.new(ActiveSupport::BufferedLogger.new(STDERR))
          logger.level = ActiveSupport::BufferedLogger::WARN
          logger.warn(
            "Rails Error: Unable to access log file. Please ensure that #{path} exists and is chmod 0666. " +
            "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
          )
          logger
        end
      end

      # Initialize cache early in the stack so railties can make use of it.
      initializer :initialize_cache, :group => :all do
        unless defined?(RAILS_CACHE)
          silence_warnings { Object.const_set "RAILS_CACHE", ActiveSupport::Cache.lookup_store(config.cache_store) }

          if RAILS_CACHE.respond_to?(:middleware)
            config.middleware.insert_before("Rack::Runtime", RAILS_CACHE.middleware)
          end
        end
      end

      # Sets the dependency loading mechanism.
      # TODO: Remove files from the $" and always use require.
      initializer :initialize_dependency_mechanism, :group => :all do
        ActiveSupport::Dependencies.mechanism = config.cache_classes ? :require : :load
      end

      initializer :bootstrap_hook, :group => :all do |app|
        ActiveSupport.run_load_hooks(:before_initialize, app)
      end
    end
  end
end
