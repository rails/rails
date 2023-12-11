# frozen_string_literal: true

require "fileutils"
require "set"
require "active_support/notifications"
require "active_support/dependencies"
require "active_support/descendants_tracker"
require "rails/secrets"

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
          warn <<~INFO
            config.eager_load is set to nil. Please update your config/environments/*.rb files accordingly:

              * development - set it to false
              * test - set it to false (unless you use a tool that preloads your test environment)
              * production - set it to true

          INFO
          config.eager_load = !config.reloading_enabled?
        end
      end

      # Initialize the logger early in the stack in case we need to log some deprecation.
      initializer :initialize_logger, group: :all do
        Rails.logger ||= config.logger || begin
          logger = if config.log_file_size
            ActiveSupport::Logger.new(config.default_log_file, 1, config.log_file_size)
          else
            ActiveSupport::Logger.new(config.default_log_file)
          end
          logger.formatter = config.log_formatter
          logger = ActiveSupport::TaggedLogging.new(logger)
          logger
        rescue StandardError
          path = config.paths["log"].first
          logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDERR))
          logger.level = ActiveSupport::Logger::WARN
          logger.warn(
            "Rails Error: Unable to access log file. Please ensure that #{path} exists and is writable " \
            "(i.e. make it writable for user and group: chmod 0664 #{path}). " \
            "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
          )
          logger
        end
        Rails.logger.level = ActiveSupport::Logger.const_get(config.log_level.to_s.upcase)

        unless Rails.logger.is_a?(ActiveSupport::BroadcastLogger)
          broadcast_logger = ActiveSupport::BroadcastLogger.new(Rails.logger)
          broadcast_logger.formatter = Rails.logger.formatter
          Rails.logger = broadcast_logger
        end

        unless config.consider_all_requests_local
          Rails.error.logger = Rails.logger
        end
      end

      # Initialize cache early in the stack so railties can make use of it.
      initializer :initialize_cache, group: :all do
        cache_format_version = config.active_support.delete(:cache_format_version)
        ActiveSupport.cache_format_version = cache_format_version if cache_format_version

        unless Rails.cache
          Rails.cache = ActiveSupport::Cache.lookup_store(*config.cache_store)

          if Rails.cache.respond_to?(:middleware)
            config.middleware.insert_before(::Rack::Runtime, Rails.cache.middleware)
          end
        end
      end

      # We setup the once autoloader this early so that engines and applications
      # are able to autoload from these paths during initialization.
      initializer :setup_once_autoloader, after: :set_eager_load_paths, before: :bootstrap_hook do
        autoloader = Rails.autoloaders.once

        # Normally empty, but if the user already defined some, we won't
        # override them. Important if there are custom namespaces associated.
        already_configured_dirs = Set.new(autoloader.dirs)

        ActiveSupport::Dependencies.autoload_once_paths.freeze
        ActiveSupport::Dependencies.autoload_once_paths.uniq.each do |path|
          # Zeitwerk only accepts existing directories in `push_dir`.
          next unless File.directory?(path)
          next if already_configured_dirs.member?(path.to_s)

          autoloader.push_dir(path)
          autoloader.do_not_eager_load(path) unless ActiveSupport::Dependencies.eager_load?(path)
        end

        autoloader.setup
      end

      initializer :bootstrap_hook, group: :all do |app|
        ActiveSupport.run_load_hooks(:before_initialize, app)
      end

      initializer :set_secrets_root, group: :all do
        Rails::Secrets.root = root
      end
    end
  end
end
