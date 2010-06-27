require 'active_support/deprecation'
require 'active_support/core_ext/string/encoding'
require 'rails/engine/configuration'

module Rails
  class Application
    class Configuration < ::Rails::Engine::Configuration
      include ::Rails::Configuration::Deprecated

      attr_accessor :allow_concurrency, :cache_classes, :cache_store,
                    :encoding, :consider_all_requests_local, :dependency_loading,
                    :filter_parameters,  :log_level, :logger, :middleware,
                    :plugins, :preload_frameworks, :reload_plugins,
                    :secret_token, :serve_static_assets, :session_options,
                    :time_zone, :whiny_nils

      def initialize(*)
        super
        @allow_concurrency = false
        @consider_all_requests_local = false
        @encoding = "utf-8"
        @filter_parameters = []
        @dependency_loading = true
        @serve_static_assets = true
        @session_store = :cookie_store
        @session_options = {}
        @time_zone = "UTC"
        @middleware = app_middleware
      end

      def encoding=(value)
        @encoding = value
        if "ruby".encoding_aware?
          Encoding.default_external = value
          Encoding.default_internal = value
        else
          $KCODE = value
          if $KCODE == "NONE"
            raise "The value you specified for config.encoding is " \
                  "invalid. The possible values are UTF8, SJIS, or EUC"
          end
        end
      end

      def paths
        @paths ||= begin
          paths = super
          paths.app.controllers << builtin_controller if builtin_controller
          paths.config.database     "config/database.yml"
          paths.config.environment  "config/environment.rb"
          paths.config.environments "config/environments", :glob => "#{Rails.env}.rb"
          paths.lib.templates       "lib/templates"
          paths.log                 "log/#{Rails.env}.log"
          paths.tmp                 "tmp"
          paths.tmp.cache           "tmp/cache"
          paths.vendor              "vendor", :load_path => true
          paths.vendor.plugins      "vendor/plugins"

          if File.exists?("#{root}/test/mocks/#{Rails.env}")
            ActiveSupport::Deprecation.warn "\"Rails.root/test/mocks/#{Rails.env}\" won't be added " <<
              "automatically to load paths anymore in future releases"
            paths.mocks_path  "test/mocks", :autoload => true, :glob => Rails.env
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
        File.expand_path('../info_routes', __FILE__) if Rails.env.development?
      end

      def log_level
        @log_level ||= Rails.env.production? ? :info : :debug
      end

      def colorize_logging
        @colorize_logging
      end

      def colorize_logging=(val)
        @colorize_logging = val
        ActiveSupport::LogSubscriber.colorize_logging = val
        self.generators.colorize_logging = val
      end

      def session_store(*args)
        if args.empty?
          case @session_store
          when :disabled
            nil
          when :active_record_store
            ActiveRecord::SessionStore
          when Symbol
            ActionDispatch::Session.const_get(@session_store.to_s.camelize)
          else
            @session_store
          end
        else
          @session_store = args.shift
          @session_options = args.shift || {}
        end
      end
    end
  end
end
