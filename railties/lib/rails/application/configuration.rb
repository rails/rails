# frozen_string_literal: true

require "ipaddr"
require "active_support/core_ext/array/wrap"
require "active_support/core_ext/kernel/reporting"
require "active_support/file_update_checker"
require "active_support/configuration_file"
require "rails/engine/configuration"
require "rails/source_annotation_extractor"

module Rails
  class Application
    class Configuration < ::Rails::Engine::Configuration
      attr_accessor :allow_concurrency, :asset_host, :assume_ssl, :autoflush_log,
                    :cache_classes, :cache_store, :consider_all_requests_local, :console,
                    :eager_load, :exceptions_app, :file_watcher, :filter_parameters, :precompile_filter_parameters,
                    :force_ssl, :helpers_paths, :hosts, :host_authorization, :logger, :log_formatter,
                    :log_tags, :railties_order, :relative_url_root,
                    :ssl_options, :public_file_server,
                    :session_options, :time_zone, :reload_classes_only_on_change,
                    :beginning_of_week, :filter_redirect, :x,
                    :content_security_policy_report_only,
                    :content_security_policy_nonce_generator, :content_security_policy_nonce_directives,
                    :require_master_key, :credentials, :disable_sandbox, :sandbox_by_default,
                    :add_autoload_paths_to_load_path, :rake_eager_load, :server_timing, :log_file_size,
                    :dom_testing_default_html_version, :yjit

      attr_reader :encoding, :api_only, :loaded_config_version, :log_level

      def initialize(*)
        super
        self.encoding                            = Encoding::UTF_8
        @allow_concurrency                       = nil
        @consider_all_requests_local             = false
        @filter_parameters                       = []
        @filter_redirect                         = []
        @helpers_paths                           = []
        if Rails.env.development?
          @hosts = ActionDispatch::HostAuthorization::ALLOWED_HOSTS_IN_DEVELOPMENT +
            ENV["RAILS_DEVELOPMENT_HOSTS"].to_s.split(",").map(&:strip)
        else
          @hosts = []
        end
        @host_authorization                      = {}
        @public_file_server                      = ActiveSupport::OrderedOptions.new
        @public_file_server.enabled              = true
        @public_file_server.index_name           = "index"
        @assume_ssl                              = false
        @force_ssl                               = false
        @ssl_options                             = {}
        @session_store                           = nil
        @time_zone                               = "UTC"
        @beginning_of_week                       = :monday
        @log_level                               = :debug
        @log_file_size                           = nil
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
        @content_security_policy                 = nil
        @content_security_policy_report_only     = false
        @content_security_policy_nonce_generator = nil
        @content_security_policy_nonce_directives = nil
        @require_master_key                      = false
        @loaded_config_version                   = nil
        @credentials                             = ActiveSupport::InheritableOptions.new(credentials_defaults)
        @disable_sandbox                         = false
        @sandbox_by_default                      = false
        @add_autoload_paths_to_load_path         = true
        @permissions_policy                      = nil
        @rake_eager_load                         = false
        @server_timing                           = false
        @dom_testing_default_html_version        = :html4
        @yjit                                    = false
      end

      # Loads default configuration values for a target version. This includes
      # defaults for versions prior to the target version. See the
      # {configuration guide}[https://guides.rubyonrails.org/configuring.html#versioned-default-values]
      # for the default values associated with a particular version.
      def load_defaults(target_version)
        # To introduce a change in behavior, follow these steps:
        # 1. Add an accessor on the target object (e.g. the ActiveJob class for
        #    global Active Job config).
        # 2. Set a default value there preserving existing behavior for existing
        #    applications.
        # 3. Implement the behavior change based on the config value.
        # 4. In the section below corresponding to the next release of Rails,
        #    configure the default value.
        # 5. Add a commented out section in the `new_framework_defaults` to
        #    configure the default value again.
        # 6. Update the guide in `configuring.md`.

        # To remove configurable deprecated behavior, follow these steps:
        # 1. Update or remove the entry in the guides.
        # 2. Remove the references below.
        # 3. Remove the legacy code paths and config check.
        # 4. Remove the config accessor.

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
            active_support.hash_digest_class = OpenSSL::Digest::SHA1
          end

          if respond_to?(:action_controller)
            action_controller.default_protect_from_forgery = true
          end

          if respond_to?(:action_view)
            action_view.form_with_generates_ids = true
          end
        when "6.0"
          load_defaults "5.2"

          if respond_to?(:action_view)
            action_view.default_enforce_utf8 = false
          end

          if respond_to?(:action_dispatch)
            action_dispatch.use_cookies_with_metadata = true
          end

          if respond_to?(:action_mailer)
            action_mailer.delivery_job = "ActionMailer::MailDeliveryJob"
          end

          if respond_to?(:active_storage)
            active_storage.queues.analysis = :active_storage_analysis
            active_storage.queues.purge    = :active_storage_purge
          end

          if respond_to?(:active_record)
            active_record.collection_cache_versioning = true
          end
        when "6.1"
          load_defaults "6.0"

          if respond_to?(:active_record)
            active_record.has_many_inversing = true
          end

          if respond_to?(:active_job)
            active_job.retry_jitter = 0.15
          end

          if respond_to?(:action_dispatch)
            action_dispatch.cookies_same_site_protection = :lax
            action_dispatch.ssl_default_redirect_status = 308
          end

          if respond_to?(:action_view)
            action_view.form_with_generates_remote_forms = false
            action_view.preload_links_header = true
          end

          if respond_to?(:active_storage)
            active_storage.track_variants = true

            active_storage.queues.analysis = nil
            active_storage.queues.purge = nil
          end

          if respond_to?(:action_mailbox)
            action_mailbox.queues.incineration = nil
            action_mailbox.queues.routing = nil
          end

          if respond_to?(:action_mailer)
            action_mailer.deliver_later_queue_name = nil
          end

          ActiveSupport.utc_to_local_returns_utc_offset_times = true
        when "7.0"
          load_defaults "6.1"

          if respond_to?(:action_dispatch)
            action_dispatch.default_headers = {
              "X-Frame-Options" => "SAMEORIGIN",
              "X-XSS-Protection" => "0",
              "X-Content-Type-Options" => "nosniff",
              "X-Download-Options" => "noopen",
              "X-Permitted-Cross-Domain-Policies" => "none",
              "Referrer-Policy" => "strict-origin-when-cross-origin"
            }
            action_dispatch.cookies_serializer = :json
          end

          if respond_to?(:action_view)
            action_view.button_to_generates_button_tag = true
            action_view.apply_stylesheet_media_default = false
          end

          if respond_to?(:active_support)
            active_support.hash_digest_class = OpenSSL::Digest::SHA256
            active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA256
            active_support.cache_format_version = 7.0
            active_support.executor_around_test_case = true
          end

          if respond_to?(:action_mailer)
            action_mailer.smtp_timeout = 5
          end

          if respond_to?(:active_storage)
            active_storage.video_preview_arguments =
              "-vf 'select=eq(n\\,0)+eq(key\\,1)+gt(scene\\,0.015),loop=loop=-1:size=2,trim=start_frame=1'" \
              " -frames:v 1 -f image2"

            active_storage.variant_processor = :vips
            active_storage.multiple_file_field_include_hidden = true
          end

          if respond_to?(:active_record)
            active_record.verify_foreign_keys_for_fixtures = true
            active_record.partial_inserts = false
            active_record.automatic_scope_inversing = true
          end

          if respond_to?(:action_controller)
            action_controller.raise_on_open_redirects = true
            action_controller.wrap_parameters_by_default = true
          end
        when "7.1"
          load_defaults "7.0"

          self.add_autoload_paths_to_load_path = false
          self.precompile_filter_parameters = true
          self.dom_testing_default_html_version = defined?(Nokogiri::HTML5) ? :html5 : :html4

          if Rails.env.local?
            self.log_file_size = 100 * 1024 * 1024
          end

          if respond_to?(:active_record)
            active_record.run_commit_callbacks_on_first_saved_instances_in_transaction = false
            active_record.sqlite3_adapter_strict_strings_by_default = true
            active_record.query_log_tags_format = :sqlcommenter
            active_record.raise_on_assign_to_attr_readonly = true
            active_record.belongs_to_required_validates_foreign_key = false
            active_record.before_committed_on_all_records = true
            active_record.default_column_serializer = nil
            active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
            active_record.encryption.support_sha1_for_non_deterministic_encryption = false
            active_record.marshalling_format_version = 7.1
            active_record.run_after_transaction_callbacks_in_order_defined = true
            active_record.generate_secure_token_on = :initialize
          end

          if respond_to?(:action_dispatch)
            action_dispatch.default_headers = {
              "X-Frame-Options" => "SAMEORIGIN",
              "X-XSS-Protection" => "0",
              "X-Content-Type-Options" => "nosniff",
              "X-Permitted-Cross-Domain-Policies" => "none",
              "Referrer-Policy" => "strict-origin-when-cross-origin"
            }
            action_dispatch.debug_exception_log_level = :error
          end

          if respond_to?(:active_support)
            active_support.cache_format_version = 7.1
            active_support.message_serializer = :json_allow_marshal
            active_support.use_message_serializer_for_metadata = true
            active_support.raise_on_invalid_cache_expiration_time = true
          end

          if respond_to?(:action_view)
            require "action_view/helpers"
            action_view.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor
          end

          if respond_to?(:action_text)
            require "action_view/helpers"
            action_text.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor
          end
        when "7.2"
          load_defaults "7.1"

          self.yjit = true

          if respond_to?(:active_job)
            active_job.enqueue_after_transaction_commit = :default
          end

          if respond_to?(:active_storage)
            active_storage.web_image_content_types = %w( image/png image/jpeg image/gif image/webp )
          end

          if respond_to?(:active_record)
            active_record.postgresql_adapter_decode_dates = true
            active_record.validate_migration_timestamps = true
          end
        else
          raise "Unknown version #{target_version.to_s.inspect}"
        end

        @loaded_config_version = target_version
      end

      def reloading_enabled?
        enable_reloading
      end

      def enable_reloading
        !cache_classes
      end

      def enable_reloading=(value)
        self.cache_classes = !value
      end

      def read_encrypted_secrets
        Rails.deprecator.warn("'config.read_encrypted_secrets' is deprecated and will be removed in Rails 8.0.")
      end

      def read_encrypted_secrets=(value)
        Rails.deprecator.warn("'config.read_encrypted_secrets=' is deprecated and will be removed in Rails 8.0.")
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

      def log_level=(level)
        @log_level = level
        @broadcast_log_level = level
      end

      attr_reader :broadcast_log_level # :nodoc:

      def debug_exception_response_format
        @debug_exception_response_format || :default
      end

      attr_writer :debug_exception_response_format

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

      # Load the <tt>config/database.yml</tt> to create the Rake tasks for
      # multiple databases without loading the environment and filling in the
      # environment specific configuration values.
      #
      # Do not use this method, use #database_configuration instead.
      def load_database_yaml # :nodoc:
        if path = paths["config/database"].existent.first
          require "rails/application/dummy_config"
          original_rails_config = Rails.application.config

          begin
            Rails.application.config = DummyConfig.new(original_rails_config)
            ActiveSupport::ConfigurationFile.parse(Pathname.new(path))
          ensure
            Rails.application.config = original_rails_config
          end
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
            loaded_yaml.each do |env, config|
              if config.is_a?(Hash) && config.values.all?(Hash)
                if shared.is_a?(Hash) && shared.values.all?(Hash)
                  config.map do |name, sub_config|
                    sub_config.reverse_merge!(shared[name])
                  end
                else
                  config.map do |name, sub_config|
                    sub_config.reverse_merge!(shared)
                  end
                end
              else
                config.reverse_merge!(shared)
              end
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

      def autoload_lib(ignore:)
        lib = root.join("lib")

        # Set as a string to have the same type as default autoload paths, for
        # consistency.
        autoload_paths << lib.to_s
        eager_load_paths << lib.to_s

        ignored_abspaths = Array.wrap(ignore).map { lib.join(_1) }
        Rails.autoloaders.main.ignore(ignored_abspaths)
      end

      def autoload_lib_once(ignore:)
        lib = root.join("lib")

        # Set as a string to have the same type as default autoload paths, for
        # consistency.
        autoload_once_paths << lib.to_s
        eager_load_paths << lib.to_s

        ignored_abspaths = Array.wrap(ignore).map { lib.join(_1) }
        Rails.autoloaders.once.ignore(ignored_abspaths)
      end

      def colorize_logging
        ActiveSupport::LogSubscriber.colorize_logging
      end

      def colorize_logging=(val)
        ActiveSupport::LogSubscriber.colorize_logging = val
        generators.colorize_logging = val
      end

      def secret_key_base
        @secret_key_base || begin
          self.secret_key_base = if generate_local_secret?
            generate_local_secret
          else
            ENV["SECRET_KEY_BASE"] || Rails.application.credentials.secret_key_base
          end
        end
      end

      def secret_key_base=(new_secret_key_base)
        if new_secret_key_base.nil? && generate_local_secret?
          @secret_key_base = generate_local_secret
        elsif new_secret_key_base.is_a?(String) && new_secret_key_base.present?
          @secret_key_base = new_secret_key_base
        elsif new_secret_key_base
          raise ArgumentError, "`secret_key_base` for #{Rails.env} environment must be a type of String`"
        else
          raise ArgumentError, "Missing `secret_key_base` for '#{Rails.env}' environment, set this string with `bin/rails credentials:edit`"
        end
      end

      # Specifies what class to use to store the session. Possible values
      # are +:cache_store+, +:cookie_store+, +:mem_cache_store+, a custom
      # store, or +:disabled+. +:disabled+ tells \Rails not to deal with
      # sessions.
      #
      # Additional options will be set as +session_options+:
      #
      #   config.session_store :cookie_store, key: "_your_app_session"
      #   config.session_options # => {key: "_your_app_session"}
      #
      # If a custom store is specified as a symbol, it will be resolved to
      # the +ActionDispatch::Session+ namespace:
      #
      #   # use ActionDispatch::Session::MyCustomStore as the session store
      #   config.session_store :my_custom_store
      def session_store(new_session_store = nil, **options)
        if new_session_store
          @session_store = new_session_store
          @session_options = options || {}
        else
          case @session_store
          when :disabled
            nil
          when Symbol
            ActionDispatch::Session.resolve_store(@session_store)
          else
            @session_store
          end
        end
      end

      def session_store? # :nodoc:
        @session_store
      end

      def annotations
        Rails::SourceAnnotationExtractor::Annotation
      end

      # Configures the ActionDispatch::ContentSecurityPolicy.
      def content_security_policy(&block)
        if block_given?
          @content_security_policy = ActionDispatch::ContentSecurityPolicy.new(&block)
        else
          @content_security_policy
        end
      end

      # Configures the ActionDispatch::PermissionsPolicy.
      def permissions_policy(&block)
        if block_given?
          @permissions_policy = ActionDispatch::PermissionsPolicy.new(&block)
        else
          @permissions_policy
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

      def inspect # :nodoc:
        "#<#{self.class.name}:#{'%#016x' % (object_id << 1)}>"
      end

      class Custom # :nodoc:
        def initialize
          @configurations = Hash.new
        end

        def method_missing(method, *args)
          if method.end_with?("=")
            @configurations[:"#{method[0..-2]}"] = args.first
          elsif args.empty?
            @configurations.fetch(method) {
              @configurations[method] = ActiveSupport::OrderedOptions.new
            }
          else
            raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0) when reading configuration `#{method}`"
          end
        end

        def respond_to_missing?(symbol, _)
          true
        end
      end

      private
        def credentials_defaults
          content_path = root.join("config/credentials/#{Rails.env}.yml.enc")
          content_path = root.join("config/credentials.yml.enc") if !content_path.exist?

          key_path = root.join("config/credentials/#{Rails.env}.key")
          key_path = root.join("config/master.key") if !key_path.exist?

          { content_path: content_path, key_path: key_path }
        end

        def generate_local_secret
          key_file = root.join("tmp/local_secret.txt")

          unless File.exist?(key_file)
            random_key = SecureRandom.hex(64)
            FileUtils.mkdir_p(key_file.dirname)
            File.binwrite(key_file, random_key)
          end

          File.binread(key_file)
        end

        def generate_local_secret?
          Rails.env.local? || ENV["SECRET_KEY_BASE_DUMMY"]
        end
    end
  end
end
