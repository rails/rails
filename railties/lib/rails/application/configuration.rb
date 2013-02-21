require 'active_support/core_ext/kernel/reporting'
require 'active_support/file_update_checker'
require 'rails/engine/configuration'

module Rails
  class Application
    class Configuration < ::Rails::Engine::Configuration
      attr_accessor :asset_host, :assets, :autoflush_log,
                    :cache_classes, :cache_store, :consider_all_requests_local, :console,
                    :eager_load, :exceptions_app, :file_watcher, :filter_parameters,
                    :force_ssl, :helpers_paths, :logger, :log_formatter, :log_tags,
                    :railties_order, :relative_url_root, :secret_key_base, :secret_token,
                    :serve_static_assets, :ssl_options, :static_cache_control, :session_options,
                    :time_zone, :reload_classes_only_on_change,
                    :beginning_of_week, :filter_redirect

      attr_writer :log_level
      attr_reader :encoding

      def initialize(*)
        super
        self.encoding = "utf-8"
        @consider_all_requests_local   = false
        @filter_parameters             = []
        @filter_redirect               = []
        @helpers_paths                 = []
        @serve_static_assets           = true
        @static_cache_control          = nil
        @force_ssl                     = false
        @ssl_options                   = {}
        @session_store                 = :cookie_store
        @session_options               = {}
        @time_zone                     = "UTC"
        @beginning_of_week             = :monday
        @log_level                     = nil
        @middleware                    = app_middleware
        @generators                    = app_generators
        @cache_store                   = [ :file_store, "#{root}/tmp/cache/" ]
        @railties_order                = [:all]
        @relative_url_root             = ENV["RAILS_RELATIVE_URL_ROOT"]
        @reload_classes_only_on_change = true
        @file_watcher                  = ActiveSupport::FileUpdateChecker
        @exceptions_app                = nil
        @autoflush_log                 = true
        @log_formatter                 = ActiveSupport::Logger::SimpleFormatter.new
        @eager_load                    = nil
        @secret_token                  = nil
        @secret_key_base               = nil

        @assets = ActiveSupport::OrderedOptions.new
        @assets.enabled                  = true
        @assets.paths                    = []
        @assets.precompile               = [ Proc.new { |path, fn| fn =~ /app\/assets/ && !%w(.js .css).include?(File.extname(path)) },
                                             /(?:\/|\\|\A)application\.(css|js)$/ ]
        @assets.prefix                   = "/assets"
        @assets.version                  = '1.0'
        @assets.debug                    = false
        @assets.compile                  = true
        @assets.digest                   = false
        @assets.cache_store              = [ :file_store, "#{root}/tmp/cache/assets/#{Rails.env}/" ]
        @assets.js_compressor            = nil
        @assets.css_compressor           = nil
        @assets.initialize_on_precompile = true
        @assets.logger                   = nil
      end

      def encoding=(value)
        @encoding = value
        silence_warnings do
          Encoding.default_external = value
          Encoding.default_internal = value
        end
      end

      def paths
        @paths ||= begin
          paths = super
          paths.add "config/database",    with: "config/database.yml"
          paths.add "config/environment", with: "config/environment.rb"
          paths.add "lib/templates"
          paths.add "log",                with: "log/#{Rails.env}.log"
          paths.add "public"
          paths.add "public/javascripts"
          paths.add "public/stylesheets"
          paths.add "tmp"
          paths
        end
      end

      def threadsafe!
        message = "config.threadsafe! is deprecated. Rails applications " \
                  "behave by default as thread safe in production as long as config.cache_classes and " \
                  "config.eager_load are set to true"
        ActiveSupport::Deprecation.warn message
        @cache_classes = true
        @eager_load = true
        self
      end

      # Loads and returns the configuration of the database.
      # First, looks at If ENV['DATABASE_URL'] if it's not present it uses the #paths["config/database"]
      # The contents of the file are processed via ERB before being sent through YAML::load. 
      def database_configuration
        if ENV['DATABASE_URL']
          {Rails.env => ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.connection_url_to_hash(ENV['DATABASE_URL']).stringify_keys}
        else
          require 'erb'
          YAML.load ERB.new(IO.read(paths["config/database"].first)).result
        end
      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing #{paths["config/database"].first}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{e.message}"
      end

      def log_level
        @log_level ||= Rails.env.production? ? :info : :debug
      end

      def colorize_logging
        ActiveSupport::LogSubscriber.colorize_logging
      end

      def colorize_logging=(val)
        ActiveSupport::LogSubscriber.colorize_logging = val
        self.generators.colorize_logging = val
      end

      def session_store(*args)
        if args.empty?
          case @session_store
          when :disabled
            nil
          when :active_record_store
            begin
              ActionDispatch::Session::ActiveRecordStore
            rescue NameError
              raise "`ActiveRecord::SessionStore` is extracted out of Rails into a gem. " \
                "Please add `activerecord-session_store` to your Gemfile to use it."
            end
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

      def whiny_nils=(*)
        ActiveSupport::Deprecation.warn "config.whiny_nils option is deprecated and no longer works"
      end
    end
  end
end
