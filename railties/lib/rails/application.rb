# frozen_string_literal: true

require "yaml"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "active_support/key_generator"
require "active_support/message_verifiers"
require "active_support/deprecation"
require "active_support/encrypted_configuration"
require "active_support/hash_with_indifferent_access"
require "active_support/configuration_file"
require "active_support/parameter_filter"
require "rails/engine"
require "rails/autoloaders"

module Rails
  # An Engine with the responsibility of coordinating the whole boot process.
  #
  # == Initialization
  #
  # Rails::Application is responsible for executing all railties and engines
  # initializers. It also executes some bootstrap initializers (check
  # Rails::Application::Bootstrap) and finishing initializers, after all the others
  # are executed (check Rails::Application::Finisher).
  #
  # == \Configuration
  #
  # Besides providing the same configuration as Rails::Engine and Rails::Railtie,
  # the application object has several specific configurations, for example
  # +enable_reloading+, +consider_all_requests_local+, +filter_parameters+,
  # +logger+, and so forth.
  #
  # Check Rails::Application::Configuration to see them all.
  #
  # == Routes
  #
  # The application object is also responsible for holding the routes and reloading routes
  # whenever the files change in development.
  #
  # == Middlewares
  #
  # The Application is also responsible for building the middleware stack.
  #
  # == Booting process
  #
  # The application is also responsible for setting up and executing the booting
  # process. From the moment you require <tt>config/application.rb</tt> in your app,
  # the booting process goes like this:
  #
  # 1.  <tt>require "config/boot.rb"</tt> to set up load paths.
  # 2.  +require+ railties and engines.
  # 3.  Define +Rails.application+ as <tt>class MyApp::Application < Rails::Application</tt>.
  # 4.  Run +config.before_configuration+ callbacks.
  # 5.  Load <tt>config/environments/ENV.rb</tt>.
  # 6.  Run +config.before_initialize+ callbacks.
  # 7.  Run <tt>Railtie#initializer</tt> defined by railties, engines, and application.
  #     One by one, each engine sets up its load paths and routes, and runs its <tt>config/initializers/*</tt> files.
  # 8.  Custom <tt>Railtie#initializers</tt> added by railties, engines, and applications are executed.
  # 9.  Build the middleware stack and run +to_prepare+ callbacks.
  # 10. Run +config.before_eager_load+ and +eager_load!+ if +eager_load+ is +true+.
  # 11. Run +config.after_initialize+ callbacks.
  class Application < Engine
    autoload :Bootstrap,              "rails/application/bootstrap"
    autoload :Configuration,          "rails/application/configuration"
    autoload :DefaultMiddlewareStack, "rails/application/default_middleware_stack"
    autoload :Finisher,               "rails/application/finisher"
    autoload :Railties,               "rails/engine/railties"
    autoload :RoutesReloader,         "rails/application/routes_reloader"

    class << self
      def inherited(base)
        super
        Rails.app_class = base
        # lib has to be added to $LOAD_PATH unconditionally, even if it's in the
        # autoload paths and config.add_autoload_paths_to_load_path is false.
        add_lib_to_load_path!(find_root(base.called_from))
        ActiveSupport.run_load_hooks(:before_configuration, base)
      end

      def instance
        super.run_load_hooks!
      end

      def create(initial_variable_values = {}, &block)
        new(initial_variable_values, &block).run_load_hooks!
      end

      def find_root(from)
        find_root_with_flag "config.ru", from, Dir.pwd
      end

      # Makes the +new+ method public.
      #
      # Note that Rails::Application inherits from Rails::Engine, which
      # inherits from Rails::Railtie and the +new+ method on Rails::Railtie is
      # private
      public :new
    end

    attr_accessor :assets, :sandbox
    alias_method :sandbox?, :sandbox
    attr_reader :reloaders, :reloader, :executor, :autoloaders

    delegate :default_url_options, :default_url_options=, to: :routes

    INITIAL_VARIABLES = [:config, :railties, :routes_reloader, :reloaders,
                         :routes, :helpers, :app_env_config] # :nodoc:

    def initialize(initial_variable_values = {}, &block)
      super()
      @initialized       = false
      @reloaders         = []
      @routes_reloader   = nil
      @app_env_config    = nil
      @ordered_railties  = nil
      @railties          = nil
      @key_generators    = {}
      @message_verifiers = nil
      @deprecators       = nil
      @ran_load_hooks    = false

      @executor          = Class.new(ActiveSupport::Executor)
      @reloader          = Class.new(ActiveSupport::Reloader)
      @reloader.executor = @executor

      @autoloaders = Rails::Autoloaders.new

      # are these actually used?
      @initial_variable_values = initial_variable_values
      @block = block
    end

    # Returns true if the application is initialized.
    def initialized?
      @initialized
    end

    # Returns the dasherized application name.
    #
    #   MyApp::Application.new.name => "my-app"
    def name
      self.class.name.underscore.dasherize.delete_suffix("/application")
    end

    def run_load_hooks! # :nodoc:
      return self if @ran_load_hooks
      @ran_load_hooks = true

      @initial_variable_values.each do |variable_name, value|
        if INITIAL_VARIABLES.include?(variable_name)
          instance_variable_set("@#{variable_name}", value)
        end
      end

      instance_eval(&@block) if @block
      self
    end

    # Reload application routes regardless if they changed or not.
    def reload_routes!
      routes_reloader.reload!
    end

    def reload_routes_unless_loaded # :nodoc:
      initialized? && routes_reloader.execute_unless_loaded
    end

    # Returns a key generator (ActiveSupport::CachingKeyGenerator) for a
    # specified +secret_key_base+. The return value is memoized, so additional
    # calls with the same +secret_key_base+ will return the same key generator
    # instance.
    def key_generator(secret_key_base = self.secret_key_base)
      # number of iterations selected based on consultation with the google security
      # team. Details at https://github.com/rails/rails/pull/6952#issuecomment-7661220
      @key_generators[secret_key_base] ||= ActiveSupport::CachingKeyGenerator.new(
        ActiveSupport::KeyGenerator.new(secret_key_base, iterations: 1000)
      )
    end

    # Returns a message verifier factory (ActiveSupport::MessageVerifiers). This
    # factory can be used as a central point to configure and create message
    # verifiers (ActiveSupport::MessageVerifier) for your application.
    #
    # By default, message verifiers created by this factory will generate
    # messages using the default ActiveSupport::MessageVerifier options. You can
    # override these options with a combination of
    # ActiveSupport::MessageVerifiers#clear_rotations and
    # ActiveSupport::MessageVerifiers#rotate. However, this must be done prior
    # to building any message verifier instances. For example, in a
    # +before_initialize+ block:
    #
    #   # Use `url_safe: true` when generating messages
    #   config.before_initialize do |app|
    #     app.message_verifiers.clear_rotations
    #     app.message_verifiers.rotate(url_safe: true)
    #   end
    #
    # Message verifiers created by this factory will always use a secret derived
    # from #secret_key_base when generating messages. +clear_rotations+ will not
    # affect this behavior. However, older +secret_key_base+ values can be
    # rotated for verifying messages:
    #
    #   # Fall back to old `secret_key_base` when verifying messages
    #   config.before_initialize do |app|
    #     app.message_verifiers.rotate(secret_key_base: "old secret_key_base")
    #   end
    #
    def message_verifiers
      @message_verifiers ||=
        ActiveSupport::MessageVerifiers.new do |salt, secret_key_base: self.secret_key_base|
          key_generator(secret_key_base).generate_key(salt)
        end.rotate_defaults
    end

    # Returns a message verifier object.
    #
    # This verifier can be used to generate and verify signed messages in the application.
    #
    # It is recommended not to use the same verifier for different things, so you can get different
    # verifiers passing the +verifier_name+ argument.
    #
    # For instance, +ActiveStorage::Blob.signed_id_verifier+ is implemented using this feature, which assures that
    # the IDs strings haven't been tampered with and are safe to use in a finder.
    #
    # See the ActiveSupport::MessageVerifier documentation for more information.
    #
    # ==== Parameters
    #
    # * +verifier_name+ - the name of the message verifier.
    #
    # ==== Examples
    #
    #     message = Rails.application.message_verifier('my_purpose').generate('data to sign against tampering')
    #     Rails.application.message_verifier('my_purpose').verify(message)
    #     # => 'data to sign against tampering'
    def message_verifier(verifier_name)
      message_verifiers[verifier_name]
    end

    # A managed collection of deprecators (ActiveSupport::Deprecation::Deprecators).
    # The collection's configuration methods affect all deprecators in the
    # collection. Additionally, the collection's +silence+ method silences all
    # deprecators in the collection for the duration of a given block.
    def deprecators
      @deprecators ||= ActiveSupport::Deprecation::Deprecators.new.tap do |deprecators|
        deprecators[:railties] = Rails.deprecator
      end
    end

    # Convenience for loading config/foo.yml for the current \Rails env.
    # Example:
    #
    #     # config/exception_notification.yml:
    #     production:
    #       url: http://127.0.0.1:8080
    #       namespace: my_app_production
    #
    #     development:
    #       url: http://localhost:3001
    #       namespace: my_app_development
    #
    # <code></code>
    #
    #     # config/environments/production.rb
    #     Rails.application.configure do
    #       config.middleware.use ExceptionNotifier, config_for(:exception_notification)
    #     end
    #
    # You can also store configurations in a shared section which will be merged
    # with the environment configuration
    #
    #     # config/example.yml
    #     shared:
    #       foo:
    #         bar:
    #           baz: 1
    #
    #     development:
    #       foo:
    #         bar:
    #           qux: 2
    #
    # <code></code>
    #
    #     # development environment
    #     Rails.application.config_for(:example)[:foo][:bar]
    #     # => { baz: 1, qux: 2 }
    def config_for(name, env: Rails.env)
      yaml = name.is_a?(Pathname) ? name : Pathname.new("#{paths["config"].existent.first}/#{name}.yml")

      if yaml.exist?
        require "erb"
        all_configs    = ActiveSupport::ConfigurationFile.parse(yaml).deep_symbolize_keys
        config, shared = all_configs[env.to_sym], all_configs[:shared]

        if shared
          config = {} if config.nil? && shared.is_a?(Hash)
          if config.is_a?(Hash) && shared.is_a?(Hash)
            config = shared.deep_merge(config)
          elsif config.nil?
            config = shared
          end
        end

        if config.is_a?(Hash)
          config = ActiveSupport::OrderedOptions.new.update(config)
        end

        config
      else
        raise "Could not load configuration. No such file - #{yaml}"
      end
    end

    # Stores some of the \Rails initial environment parameters which
    # will be used by middlewares and engines to configure themselves.
    def env_config
      @app_env_config ||= super.merge(
          "action_dispatch.parameter_filter" => filter_parameters,
          "action_dispatch.redirect_filter" => config.filter_redirect,
          "action_dispatch.secret_key_base" => secret_key_base,
          "action_dispatch.show_exceptions" => config.action_dispatch.show_exceptions,
          "action_dispatch.show_detailed_exceptions" => config.consider_all_requests_local,
          "action_dispatch.log_rescued_responses" => config.action_dispatch.log_rescued_responses,
          "action_dispatch.debug_exception_log_level" => ActiveSupport::Logger.const_get(config.action_dispatch.debug_exception_log_level.to_s.upcase),
          "action_dispatch.logger" => Rails.logger,
          "action_dispatch.backtrace_cleaner" => Rails.backtrace_cleaner,
          "action_dispatch.key_generator" => key_generator,
          "action_dispatch.http_auth_salt" => config.action_dispatch.http_auth_salt,
          "action_dispatch.signed_cookie_salt" => config.action_dispatch.signed_cookie_salt,
          "action_dispatch.encrypted_cookie_salt" => config.action_dispatch.encrypted_cookie_salt,
          "action_dispatch.encrypted_signed_cookie_salt" => config.action_dispatch.encrypted_signed_cookie_salt,
          "action_dispatch.authenticated_encrypted_cookie_salt" => config.action_dispatch.authenticated_encrypted_cookie_salt,
          "action_dispatch.use_authenticated_cookie_encryption" => config.action_dispatch.use_authenticated_cookie_encryption,
          "action_dispatch.encrypted_cookie_cipher" => config.action_dispatch.encrypted_cookie_cipher,
          "action_dispatch.signed_cookie_digest" => config.action_dispatch.signed_cookie_digest,
          "action_dispatch.cookies_serializer" => config.action_dispatch.cookies_serializer,
          "action_dispatch.cookies_digest" => config.action_dispatch.cookies_digest,
          "action_dispatch.cookies_rotations" => config.action_dispatch.cookies_rotations,
          "action_dispatch.cookies_same_site_protection" => coerce_same_site_protection(config.action_dispatch.cookies_same_site_protection),
          "action_dispatch.use_cookies_with_metadata" => config.action_dispatch.use_cookies_with_metadata,
          "action_dispatch.content_security_policy" => config.content_security_policy,
          "action_dispatch.content_security_policy_report_only" => config.content_security_policy_report_only,
          "action_dispatch.content_security_policy_nonce_generator" => config.content_security_policy_nonce_generator,
          "action_dispatch.content_security_policy_nonce_directives" => config.content_security_policy_nonce_directives,
          "action_dispatch.permissions_policy" => config.permissions_policy,
        )
    end

    # If you try to define a set of Rake tasks on the instance, these will get
    # passed up to the Rake tasks defined on the application's class.
    def rake_tasks(&block)
      self.class.rake_tasks(&block)
    end

    # Sends the initializers to the +initializer+ method defined in the
    # Rails::Initializable module. Each Rails::Application class has its own
    # set of initializers, as defined by the Initializable module.
    def initializer(name, opts = {}, &block)
      self.class.initializer(name, opts, &block)
    end

    # Sends any runner called in the instance of a new application up
    # to the +runner+ method defined in Rails::Railtie.
    def runner(&blk)
      self.class.runner(&blk)
    end

    # Sends any console called in the instance of a new application up
    # to the +console+ method defined in Rails::Railtie.
    def console(&blk)
      self.class.console(&blk)
    end

    # Sends any generators called in the instance of a new application up
    # to the +generators+ method defined in Rails::Railtie.
    def generators(&blk)
      self.class.generators(&blk)
    end

    # Sends any server called in the instance of a new application up
    # to the +server+ method defined in Rails::Railtie.
    def server(&blk)
      self.class.server(&blk)
    end

    # Sends the +isolate_namespace+ method up to the class method.
    def isolate_namespace(mod)
      self.class.isolate_namespace(mod)
    end

    ## Rails internal API

    # This method is called just after an application inherits from Rails::Application,
    # allowing the developer to load classes in lib and use them during application
    # configuration.
    #
    #   class MyApplication < Rails::Application
    #     require "my_backend" # in lib/my_backend
    #     config.i18n.backend = MyBackend
    #   end
    #
    # Notice this method takes into consideration the default root path. So if you
    # are changing config.root inside your application definition or having a custom
    # Rails application, you will need to add lib to $LOAD_PATH on your own in case
    # you need to load files in lib/ during the application configuration as well.
    def self.add_lib_to_load_path!(root) # :nodoc:
      path = File.join(root, "lib")
      if File.exist?(path) && !$LOAD_PATH.include?(path)
        $LOAD_PATH.unshift(path)
      end
    end

    def require_environment! # :nodoc:
      environment = paths["config/environment"].existent.first
      require environment if environment
    end

    def routes_reloader # :nodoc:
      @routes_reloader ||= RoutesReloader.new
    end

    # Returns an array of file paths appended with a hash of
    # directories-extensions suitable for ActiveSupport::FileUpdateChecker
    # API.
    def watchable_args # :nodoc:
      files, dirs = config.watchable_files.dup, config.watchable_dirs.dup

      Rails.autoloaders.main.dirs.each do |path|
        dirs[path] = [:rb]
      end

      [files, dirs]
    end

    # Initialize the application passing the given group. By default, the
    # group is :default
    def initialize!(group = :default) # :nodoc:
      raise "Application has been already initialized." if @initialized
      run_initializers(group, self)
      @initialized = true
      self
    end

    def initializers # :nodoc:
      Bootstrap.initializers_for(self) +
      railties_initializers(super) +
      Finisher.initializers_for(self)
    end

    def config # :nodoc:
      @config ||= Application::Configuration.new(self.class.find_root(self.class.called_from))
    end

    attr_writer :config
    attr_writer :credentials

    # The secret_key_base is used as the input secret to the application's key generator, which in turn
    # is used to create all ActiveSupport::MessageVerifier and ActiveSupport::MessageEncryptor instances,
    # including the ones that sign and encrypt cookies.
    #
    # In development and test, this is randomly generated and stored in a
    # temporary file in <tt>tmp/local_secret.txt</tt>.
    #
    # You can also set <tt>ENV["SECRET_KEY_BASE_DUMMY"]</tt> to trigger the use of a randomly generated
    # secret_key_base that's stored in a temporary file. This is useful when precompiling assets for
    # production as part of a build step that otherwise does not need access to the production secrets.
    #
    # Dockerfile example: <tt>RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile</tt>.
    #
    # In all other environments, we look for it first in <tt>ENV["SECRET_KEY_BASE"]</tt>,
    # then +credentials.secret_key_base+. For most applications, the correct place to store it is in the
    # encrypted credentials file.
    def secret_key_base
      config.secret_key_base
    end

    # Returns an ActiveSupport::EncryptedConfiguration instance for the
    # credentials file specified by +config.credentials.content_path+.
    #
    # By default, +config.credentials.content_path+ will point to either
    # <tt>config/credentials/#{environment}.yml.enc</tt> for the current
    # environment (for example, +config/credentials/production.yml.enc+ for the
    # +production+ environment), or +config/credentials.yml.enc+ if that file
    # does not exist.
    #
    # The encryption key is taken from either <tt>ENV["RAILS_MASTER_KEY"]</tt>,
    # or from the file specified by +config.credentials.key_path+. By default,
    # +config.credentials.key_path+ will point to either
    # <tt>config/credentials/#{environment}.key</tt> for the current
    # environment, or +config/master.key+ if that file does not exist.
    def credentials
      @credentials ||= encrypted(config.credentials.content_path, key_path: config.credentials.key_path)
    end

    # Returns an ActiveSupport::EncryptedConfiguration instance for an encrypted
    # file. By default, the encryption key is taken from either
    # <tt>ENV["RAILS_MASTER_KEY"]</tt>, or from the +config/master.key+ file.
    #
    #   my_config = Rails.application.encrypted("config/my_config.enc")
    #
    #   my_config.read
    #   # => "foo:\n  bar: 123\n"
    #
    #   my_config.foo.bar
    #   # => 123
    #
    # Encrypted files can be edited with the <tt>bin/rails encrypted:edit</tt>
    # command. (See the output of <tt>bin/rails encrypted:edit --help</tt> for
    # more information.)
    def encrypted(path, key_path: "config/master.key", env_key: "RAILS_MASTER_KEY")
      ActiveSupport::EncryptedConfiguration.new(
        config_path: Rails.root.join(path),
        key_path: Rails.root.join(key_path),
        env_key: env_key,
        raise_if_missing_key: config.require_master_key
      )
    end

    def to_app # :nodoc:
      self
    end

    def helpers_paths # :nodoc:
      config.helpers_paths
    end

    console do
      unless ::Kernel.private_method_defined?(:y)
        require "psych/y"
      end
    end

    # Return an array of railties respecting the order they're loaded
    # and the order specified by the +railties_order+ config.
    #
    # While running initializers we need engines in reverse order here when
    # copying migrations from railties ; we need them in the order given by
    # +railties_order+.
    def migration_railties # :nodoc:
      ordered_railties.flatten - [self]
    end

    def load_generators(app = self) # :nodoc:
      app.ensure_generator_templates_added
      super
    end

    # Eager loads the application code.
    def eager_load!
      Rails.autoloaders.each(&:eager_load)
    end

  protected
    alias :build_middleware_stack :app

    def run_tasks_blocks(app) # :nodoc:
      railties.each { |r| r.run_tasks_blocks(app) }
      super
      load "rails/tasks.rb"
      task :environment do
        ActiveSupport.on_load(:before_initialize) { config.eager_load = config.rake_eager_load }

        require_environment!
      end
    end

    def run_generators_blocks(app) # :nodoc:
      railties.each { |r| r.run_generators_blocks(app) }
      super
    end

    def run_runner_blocks(app) # :nodoc:
      railties.each { |r| r.run_runner_blocks(app) }
      super
    end

    def run_console_blocks(app) # :nodoc:
      railties.each { |r| r.run_console_blocks(app) }
      super
    end

    def run_server_blocks(app) # :nodoc:
      railties.each { |r| r.run_server_blocks(app) }
      super
    end

    # Returns the ordered railties for this application considering railties_order.
    def ordered_railties # :nodoc:
      @ordered_railties ||= begin
        order = config.railties_order.map do |railtie|
          if railtie == :main_app
            self
          elsif railtie.respond_to?(:instance)
            railtie.instance
          else
            railtie
          end
        end

        all = (railties - order)
        all.push(self)   unless (all + order).include?(self)
        order.push(:all) unless order.include?(:all)

        index = order.index(:all)
        order[index] = all
        order
      end
    end

    def railties_initializers(current) # :nodoc:
      initializers = Initializable::Collection.new
      ordered_railties.reverse.flatten.each do |r|
        if r == self
          initializers += current
        else
          initializers += r.initializers
        end
      end
      initializers
    end

    def default_middleware_stack # :nodoc:
      default_stack = DefaultMiddlewareStack.new(self, config, paths)
      default_stack.build_stack
    end

    def ensure_generator_templates_added
      configured_paths = config.generators.templates
      configured_paths.unshift(*(paths["lib/templates"].existent - configured_paths))
    end

    private
      def build_request(env)
        req = super
        env["ORIGINAL_FULLPATH"] = req.fullpath
        env["ORIGINAL_SCRIPT_NAME"] = req.script_name
        req
      end

      def build_middleware
        config.app_middleware + super
      end

      def coerce_same_site_protection(protection)
        protection.respond_to?(:call) ? protection : proc { protection }
      end

      def filter_parameters
        if config.precompile_filter_parameters
          config.filter_parameters.replace(
            ActiveSupport::ParameterFilter.precompile_filters(config.filter_parameters)
          )
        end
        config.filter_parameters
      end
  end
end
