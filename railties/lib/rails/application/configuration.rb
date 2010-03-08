require 'rails/engine/configuration'

module Rails
  class Application
    class Configuration < ::Rails::Engine::Configuration
      include ::Rails::Configuration::Deprecated

      attr_accessor :allow_concurrency, :cache_classes, :cache_store,
                    :consider_all_requests_local, :dependency_loading,
                    :filter_parameters,  :log_level, :logger, :metals,
                    :plugins, :preload_frameworks, :reload_engines, :reload_plugins,
                    :serve_static_assets, :time_zone, :whiny_nils

      def initialize(*)
        super
        @allow_concurrency   = false
        @filter_parameters   = []
        @dependency_loading  = true
        @serve_static_assets = true
        @time_zone           = "UTC"
        @consider_all_requests_local = true
      end

      def middleware
        @@default_middleware_stack ||= default_middleware
      end

      def paths
        @paths ||= begin
          paths = super
          paths.app.controllers << builtin_controller if builtin_controller
          paths.config.database    "config/database.yml"
          paths.config.environment "config/environments", :glob => "#{Rails.env}.rb"
          paths.log                "log/#{Rails.env}.log"
          paths.tmp                "tmp"
          paths.tmp.cache          "tmp/cache"
          paths.vendor             "vendor", :load_path => true
          paths.vendor.plugins     "vendor/plugins"

          if File.exists?("#{root}/test/mocks/#{Rails.env}")
            ActiveSupport::Deprecation.warn "\"RAILS_ROOT/test/mocks/#{Rails.env}\" won't be added " <<
              "automatically to load paths anymore in future releases"
            paths.mocks_path  "test/mocks", :load_path => true, :glob => Rails.env
          end

          paths
        end
      end

      # Enable threaded mode. Allows concurrent requests to controller actions and
      # multiple database connections. Also disables automatic dependency loading
      # after boot, and disables reloading code on every request, as these are
      # fundamentally incompatible with thread safety.
      def threadsafe!
        self.preload_frameworks = true
        self.cache_classes = true
        self.dependency_loading = false
        self.allow_concurrency = true
        self
      end

      # Loads and returns the contents of the #database_configuration_file. The
      # contents of the file are processed via ERB before being sent through
      # YAML::load.
      def database_configuration
        require 'erb'
        YAML::load(ERB.new(IO.read(paths.config.database.to_a.first)).result)
      end

      def cache_store
        @cache_store ||= begin
          if File.exist?("#{root}/tmp/cache/")
            [ :file_store, "#{root}/tmp/cache/" ]
          else
            :memory_store
          end
        end
      end

      def builtin_controller
        File.join(RAILTIES_PATH, "builtin", "rails_info") if Rails.env.development?
      end

      def log_level
        @log_level ||= Rails.env.production? ? :info : :debug
      end

      def colorize_logging
        @colorize_logging
      end

      def colorize_logging=(val)
        @colorize_logging = val
        Rails::LogSubscriber.colorize_logging = val
        self.generators.colorize_logging = val
      end
    end
  end
end