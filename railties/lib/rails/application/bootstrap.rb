require "active_support/notifications"
require "active_support/dependencies"
require "active_support/descendants_tracker"

module Rails
  class Application
    module Bootstrap
      include Initializable

      initializer :load_environment_hook, group: :all do end

      initializer :load_active_support, group: :all do
        require "active_support/all" unless config.active_support.bare
      end

      initializer :set_eager_load, group: :all do
        if config.eager_load.nil?
          warn <<-INFO
config.eager_load is set to nil. Please update your config/environments/*.rb files accordingly:

  * development - set it to false
  * test - set it to false (unless you use a tool that preloads your test environment)
  * production - set it to true

INFO
          config.eager_load = config.cache_classes
        end
      end

      # Initialize the logger early in the stack in case we need to log some deprecation.
      initializer :initialize_logger, group: :all do
        Rails.logger ||= config.logger || begin
          path = config.paths["log"].first
          unless File.exist? File.dirname path
            FileUtils.mkdir_p File.dirname path
          end

          f = File.open path, 'a'
          f.binmode
          f.sync = config.autoflush_log # if true make sure every write flushes

          logger = ActiveSupport::Logger.new f
          logger.formatter = config.log_formatter
          logger = ActiveSupport::TaggedLogging.new(logger)
          logger
        rescue StandardError
          logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDERR))
          logger.level = ActiveSupport::Logger::WARN
          logger.warn(
            "Rails Error: Unable to access log file. Please ensure that #{path} exists and is chmod 0666. " +
            "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
          )
          logger
        end

        Rails.logger.level = ActiveSupport::Logger.const_get(config.log_level.to_s.upcase)
      end

      # Initialize cache early in the stack so railties can make use of it.
      initializer :initialize_cache, group: :all do
        unless Rails.cache
          Rails.cache = ActiveSupport::Cache.lookup_store(config.cache_store)

          if Rails.cache.respond_to?(:middleware)
            config.middleware.insert_before("Rack::Runtime", Rails.cache.middleware)
          end
        end
      end

      # Sets the dependency loading mechanism.
      initializer :initialize_dependency_mechanism, group: :all do
        ActiveSupport::Dependencies.mechanism = config.cache_classes ? :require : :load
      end

      initializer :bootstrap_hook, group: :all do |app|
        ActiveSupport.run_load_hooks(:before_initialize, app)
      end
    end
  end
end
