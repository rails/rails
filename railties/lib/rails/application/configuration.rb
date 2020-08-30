# frozen_string_literal: true

require "ipaddr"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/symbol/starts_ends_with"
require "active_support/file_update_checker"
require "active_support/configuration_file"
require "rails/engine/configuration"
require "rails/source_annotation_extractor"

module Rails
  class Application
    class Configuration < ::Rails::Engine::Configuration
      attr_accessor :allow_concurrency, :asset_host, :autoflush_log,
                    :cache_classes, :cache_store, :consider_all_requests_local, :console,
                    :eager_load, :exceptions_app, :file_watcher, :filter_parameters,
                    :force_ssl, :helpers_paths, :hosts, :logger, :log_formatter, :log_tags,
                    :railties_order, :relative_url_root, :secret_key_base,
                    :ssl_options, :public_file_server,
                    :session_options, :time_zone, :reload_classes_only_on_change,
                    :beginning_of_week, :filter_redirect, :x, :enable_dependency_loading,
                    :read_encrypted_secrets, :log_level, :content_security_policy_report_only,
                    :content_security_policy_nonce_generator, :content_security_policy_nonce_directives,
                    :require_master_key, :credentials, :disable_sandbox, :add_autoload_paths_to_load_path,
                    :rake_eager_load

      attr_reader :encoding, :api_only, :loaded_config_version, :autoloader

      def initialize(*)
        super
        self.encoding                            = Encoding::UTF_8
        @allow_concurrency                       = nil
        @consider_all_requests_local             = false
        @filter_parameters                       = []
        @filter_redirect                         = []
        @helpers_paths                           = []
        @hosts                                   = Array(([".localhost", IPAddr.new("0.0.0.0/0"), IPAddr.new("::/0")] if Rails.env.development?))
        @public_file_server                      = ActiveSupport::OrderedOptions.new
        @public_file_server.enabled              = true
        @public_file_server.index_name           = "index"
        @force_ssl                               = false
        @ssl_options                             = {}
        @session_store                           = nil
        @time_zone                               = "UTC"
        @beginning_of_week                       = :monday
        @log_level                               = :debug
        @generators                              = app_generators
        @cache_store                             = [ :file_store, "#{root}/tmp/cache/" ]
        @railties_order                          = [:all]
        @relative_url_root                       = ENV["RAILS_RELATIVE_URL_ROOT"]
        @reload_classes_only_on_change           = true
        @file_watcher                            = ActiveSupport::FileUpdateChecker
        @exceptions_app                          = nil
        @autoflush_log                           = true
        @log_formatter                           = ActiveSupport::Logger::SimpleFormatter.new
        @eager_load                              = nil
        @secret_key_base                         = nil
        @api_only                                = false
        @debug_exception_response_format         = nil
        @x                                       = Custom.new
        @enable_dependency_loading               = false
        @read_encrypted_secrets                  = false
        @content_security_policy                 = nil
        @content_security_policy_report_only     = false
        @content_security_policy_nonce_generator = nil
        @content_security_policy_nonce_directives = nil
        @require_master_key                      = false
        @loaded_config_version                   = nil
        @credentials                             = ActiveSupport::OrderedOptions.new
        @credentials.content_path                = default_credentials_content_path
        @credentials.key_path                    = default_credentials_key_path
        @autoloader                              = :classic
        @disable_sandbox                         = false
        @add_autoload_paths_to_load_path         = true
        @feature_policy                          = nil
        @rake_eager_load                         = false
      end

      # Loads default configurations. See {the result of the method for each version}[https://guides.rubyonrails.org/configuring.html#results-of-config-load-defaults].
      def load_defaults(target_version)
        case target_version.to_s
        when "5.0"
          if respond_to?(:action_controller)
            action_controller.per_form_csrf_tokens = true
            action_controller.forgery_protection_origin_check = true
          end

          ActiveSupport.to_time_preserves_timezone = true

          if respond_to?(:active_record)
            active_record.belongs_to_required_by_default = true
          end

          self.ssl_options = { hsts: { subdomains: true } }
        when "5.1"
          load_defaults "5.0"

          if respond_to?(:assets)
            assets.unknown_asset_fallback = false
          end

          if respond_to?(:action_view)
            action_view.form_with_generates_remote_forms = true
          end
        when "5.2"
          load_defaults "5.1"

          if respond_to?(:active_record)
            active_record.cache_versioning = true
          end

          if respond_to?(:action_dispatch)
            action_dispatch.use_authenticated_cookie_encryption = true
          end

          if respond_to?(:active_support)
            active_support.use_authenticated_message_encryption = true
            active_support.use_sha1_digests = true
          end

          if respond_to?(:action_controller)
            action_controller.default_protect_from_forgery = true
          end

          if respond_to?(:action_view)
            action_view.form_with_generates_ids = true
          end
        when "6.0"
          load_defaults "5.2"

          self.autoloader = :zeitwerk if %w[ruby truffleruby].include?(RUBY_ENGINE)

          if respond_to?(:action_view)
            action_view.default_enforce_utf8 = false
          end

          if respond_to?(:action_dispatch)
            action_dispatch.use_cookies_with_metadata = true
            action_dispatch.return_only_media_type_on_content_type = false
          end

          if respond_to?(:action_mailer)
            action_mailer.delivery_job = "ActionMailer::MailDeliveryJob"
          end

          if respond_to?(:active_job)
            active_job.return_false_on_aborted_enqueue = true
          end

          if respond_to?(:active_storage)
            active_storage.queues.analysis = :active_storage_analysis
            active_storage.queues.purge    = :active_storage_purge

            active_storage.replace_on_assign_to_many = true
          end

          if respond_to?(:active_record)
            active_record.collection_cache_versioning = true
          end
        when "6.1"
          load_defaults "6.0"

          if respond_to?(:active_record)
            active_record.has_many_inversing = true
          end

          if respond_to?(:active_storage)
            active_storage.track_variants = true
          end

          if respond_to?(:active_job)
            active_job.retry_jitter = 0.15
            active_job.skip_after_callbacks_if_terminated = true
          end

          if respond_to?(:action_dispatch)
            action_dispatch.cookies_same_site_protection = :lax
            action_dispatch.ssl_default_redirect_status = 308
          end

          if respond_to?(:action_controller)
            action_controller.urlsafe_csrf_tokens = true
          end

          ActiveSupport.utc_to_local_returns_utc_offset_times = true
        else
          raise "Unknown version #{target_version.to_s.inspect}"
        end

        @loaded_config_version = target_version
      end

      def encoding=(value)
        @encoding = value
        silence_warnings do
          Encoding.default_external = value
          Encoding.default_internal = value
        end
      end

      def api_only=(value)
        @api_only = value
        generators.api_only = value

        @debug_exception_response_format ||= :api
      end

      def debug_exception_response_format
        @debug_exception_response_format || :default
      end

      attr_writer :debug_exception_response_format

      def paths
        @paths ||= begin
          paths = super
          paths.add "config/database",    with: "config/database.yml"
          paths.add "config/secrets",     with: "config", glob: "secrets.yml{,.enc}"
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

      # Load the database YAML without evaluating ERB. This allows us to
      # create the rake tasks for multiple databases without filling in the
      # configuration values or loading the environment. Do not use this
      # method.
      #
      # This uses a DummyERB custom compiler so YAML can ignore the ERB
      # tags and load the database.yml for the rake tasks.
      def load_database_yaml # :nodoc:
        if path = paths["config/database"].existent.first
          require "rails/application/dummy_erb_compiler"

          yaml = Pathname.new(path)
          erb = DummyERB.new(yaml.read)

          YAML.load(erb.result) || {}
        else
          {}
        end
      end

      # Loads and returns the entire raw configuration of database from
      # values stored in <tt>config/database.yml</tt>.
      def database_configuration
        path = paths["config/database"].existent.first
        yaml = Pathname.new(path) if path

        config = if yaml&.exist?
          loaded_yaml = ActiveSupport::ConfigurationFile.parse(yaml)
          if (shared = loaded_yaml.delete("shared"))
            loaded_yaml.each do |_k, values|
              values.reverse_merge!(shared)
            end
          end
          Hash.new(shared).merge(loaded_yaml)
        elsif ENV["DATABASE_URL"]
          # Value from ENV['DATABASE_URL'] is set to default database connection
          # by Active Record.
          {}
        else
          raise "Could not load database configuration. No such file - #{paths["config/database"].instance_variable_get(:@paths)}"
        end

        config
      rescue => e
        raise e, "Cannot load database configuration:\n#{e.message}", e.backtrace
      end

      def colorize_logging
        ActiveSupport::LogSubscriber.colorize_logging
      end

      def colorize_logging=(val)
        ActiveSupport::LogSubscriber.colorize_logging = val
        generators.colorize_logging = val
      end

      def session_store(new_session_store = nil, **options)
        if new_session_store
          if new_session_store == :active_record_store
            begin
              ActionDispatch::Session::ActiveRecordStore
            rescue NameError
              raise "`ActiveRecord::SessionStore` is extracted out of Rails into a gem. " \
                "Please add `activerecord-session_store` to your Gemfile to use it."
            end
          end

          @session_store = new_session_store
          @session_options = options || {}
        else
          case @session_store
          when :disabled
            nil
          when :active_record_store
            ActionDispatch::Session::ActiveRecordStore
          when Symbol
            ActionDispatch::Session.const_get(@session_store.to_s.camelize)
          else
            @session_store
          end
        end
      end

      def session_store? #:nodoc:
        @session_store
      end

      def annotations
        Rails::SourceAnnotationExtractor::Annotation
      end

      def content_security_policy(&block)
        if block_given?
          @content_security_policy = ActionDispatch::ContentSecurityPolicy.new(&block)
        else
          @content_security_policy
        end
      end

      def feature_policy(&block)
        if block_given?
          @feature_policy = ActionDispatch::FeaturePolicy.new(&block)
        else
          @feature_policy
        end
      end

      def autoloader=(autoloader)
        case autoloader
        when :classic
          @autoloader = autoloader
        when :zeitwerk
          require "zeitwerk"
          @autoloader = autoloader
        else
          raise ArgumentError, "config.autoloader may be :classic or :zeitwerk, got #{autoloader.inspect} instead"
        end
      end

      def default_log_file
        path = paths["log"].first
        unless File.exist? File.dirname path
          FileUtils.mkdir_p File.dirname path
        end

        f = File.open path, "a"
        f.binmode
        f.sync = autoflush_log # if true make sure every write flushes
        f
      end

      class Custom #:nodoc:
        def initialize
          @configurations = Hash.new
        end

        def method_missing(method, *args)
          if method.end_with?("=")
            @configurations[:"#{method[0..-2]}"] = args.first
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

      private
        def default_credentials_content_path
          if credentials_available_for_current_env?
            root.join("config", "credentials", "#{Rails.env}.yml.enc")
          else
            root.join("config", "credentials.yml.enc")
          end
        end

        def default_credentials_key_path
          if credentials_available_for_current_env?
            root.join("config", "credentials", "#{Rails.env}.key")
          else
            root.join("config", "master.key")
          end
        end

        def credentials_available_for_current_env?
          File.exist?(root.join("config", "credentials", "#{Rails.env}.yml.enc"))
        end
    end
  end
end
