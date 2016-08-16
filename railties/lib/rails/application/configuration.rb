require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/string/filters'
require 'active_support/file_update_checker'
require 'active_support/deprecation'
require 'rails/engine/configuration'
require 'rails/source_annotation_extractor'

module Rails
  class Application
    class Configuration < ::Rails::Engine::Configuration
      attr_accessor :allow_concurrency, :asset_host, :assets, :autoflush_log,
                    :cache_classes, :cache_store, :consider_all_requests_local, :console,
                    :eager_load, :exceptions_app, :file_watcher, :filter_parameters,
                    :force_ssl, :helpers_paths, :logger, :log_formatter, :log_tags,
                    :railties_order, :relative_url_root, :secret_key_base, :secret_token,
                    :serve_static_files, :ssl_options, :static_cache_control, :session_options,
                    :time_zone, :reload_classes_only_on_change,
                    :beginning_of_week, :filter_redirect, :x

      attr_reader :encoding

      def initialize(*)
        super
        self.encoding = "utf-8"
        @allow_concurrency             = nil
        @consider_all_requests_local   = false
        @filter_parameters             = []
        @filter_redirect               = []
        @helpers_paths                 = []
        @serve_static_files            = true
        @static_cache_control          = nil
        @force_ssl                     = false
        @ssl_options                   = {}
        @session_store                 = :cookie_store
        @session_options               = {}
        @time_zone                     = "UTC"
        @beginning_of_week             = :monday
        @has_explicit_log_level        = false
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
        @x                             = Custom.new

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
          paths.add "config/secrets",     with: "config/secrets.yml"
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

      # Loads and returns the entire raw configuration of database from
      # values stored in `config/database.yml`.
      def database_configuration
        path = paths["config/database"].existent.first
        yaml = Pathname.new(path) if path

        config = if yaml && yaml.exist?
          require "yaml"
          require "erb"
          YAML.load(ERB.new(yaml.read).result) || {}
        elsif ENV['DATABASE_URL']
          # Value from ENV['DATABASE_URL'] is set to default database connection
          # by Active Record.
          {}
        else
          raise "Could not load database configuration. No such file - #{paths["config/database"].instance_variable_get(:@paths)}"
        end

        config
      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing #{paths["config/database"].first}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{e.message}"
      rescue => e
        raise e, "Cannot load `Rails.application.database_configuration`:\n#{e.message}", e.backtrace
      end

      def has_explicit_log_level? # :nodoc:
        @has_explicit_log_level
      end

      def log_level=(level)
        @has_explicit_log_level = !!(level)
        @log_level = level
      end

      def log_level
        @log_level ||= (Rails.env.production? ? :info : :debug)
      end

      def colorize_logging
        ActiveSupport::LogSubscriber.colorize_logging
      end

      def colorize_logging=(val)
        ActiveSupport::LogSubscriber.colorize_logging = val
        self.generators.colorize_logging = val
      end

      # :nodoc:
      SERVE_STATIC_ASSETS_DEPRECATION_MESSAGE = <<-MSG.squish
        The configuration option `config.serve_static_assets` has been renamed
        to `config.serve_static_files` to clarify its role (it merely enables
        serving everything in the `public` folder and is unrelated to the asset
        pipeline). The `serve_static_assets` alias will be removed in Rails 5.0.
        Please migrate your configuration files accordingly.
      MSG

      def serve_static_assets
        ActiveSupport::Deprecation.warn SERVE_STATIC_ASSETS_DEPRECATION_MESSAGE
        serve_static_files
      end

      def serve_static_assets=(value)
        ActiveSupport::Deprecation.warn SERVE_STATIC_ASSETS_DEPRECATION_MESSAGE
        self.serve_static_files = value
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

      def annotations
        SourceAnnotationExtractor::Annotation
      end

      private
        class Custom #:nodoc:
          def initialize
            @configurations = Hash.new
          end

          def method_missing(method, *args)
            if method =~ /=$/
              @configurations[$`.to_sym] = args.first
            else
              @configurations.fetch(method) {
                @configurations[method] = ActiveSupport::OrderedOptions.new
              }
            end
          end

          def respond_to_missing?(symbol, *)
            true
          end
        end
    end
  end
end
