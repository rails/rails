require "yaml"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "active_support/key_generator"
require "active_support/message_verifier"
require "rails/engine"

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
  # == Configuration
  #
  # Besides providing the same configuration as Rails::Engine and Rails::Railtie,
  # the application object has several specific configurations, for example
  # "cache_classes", "consider_all_requests_local", "filter_parameters",
  # "logger" and so forth.
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
  # process. From the moment you require "config/application.rb" in your app,
  # the booting process goes like this:
  #
  #   1)  require "config/boot.rb" to setup load paths
  #   2)  require railties and engines
  #   3)  Define Rails.application as "class MyApp::Application < Rails::Application"
  #   4)  Run config.before_configuration callbacks
  #   5)  Load config/environments/ENV.rb
  #   6)  Run config.before_initialize callbacks
  #   7)  Run Railtie#initializer defined by railties, engines and application.
  #       One by one, each engine sets up its load paths, routes and runs its config/initializers/* files.
  #   8)  Custom Railtie#initializers added by railties, engines and applications are executed
  #   9)  Build the middleware stack and run to_prepare callbacks
  #   10) Run config.before_eager_load and eager_load! if eager_load is true
  #   11) Run config.after_initialize callbacks
  #
  # == Multiple Applications
  #
  # If you decide to define multiple applications, then the first application
  # that is initialized will be set to +Rails.application+, unless you override
  # it with a different application.
  #
  # To create a new application, you can instantiate a new instance of a class
  # that has already been created:
  #
  #   class Application < Rails::Application
  #   end
  #
  #   first_application  = Application.new
  #   second_application = Application.new(config: first_application.config)
  #
  # In the above example, the configuration from the first application was used
  # to initialize the second application. You can also use the +initialize_copy+
  # on one of the applications to create a copy of the application which shares
  # the configuration.
  #
  # If you decide to define rake tasks, runners, or initializers in an
  # application other than +Rails.application+, then you must run them manually.
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
        add_lib_to_load_path!(find_root(base.called_from))
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
    attr_reader :reloaders, :reloader, :executor

    delegate :default_url_options, :default_url_options=, to: :routes

    INITIAL_VARIABLES = [:config, :railties, :routes_reloader, :reloaders,
                         :routes, :helpers, :app_env_config, :secrets] # :nodoc:

    def initialize(initial_variable_values = {}, &block)
      super()
      @initialized       = false
      @reloaders         = []
      @routes_reloader   = nil
      @app_env_config    = nil
      @ordered_railties  = nil
      @railties          = nil
      @message_verifiers = {}
      @ran_load_hooks    = false

      @executor          = Class.new(ActiveSupport::Executor)
      @reloader          = Class.new(ActiveSupport::Reloader)
      @reloader.executor = @executor

      # are these actually used?
      @initial_variable_values = initial_variable_values
      @block = block
    end

    # Returns true if the application is initialized.
    def initialized?
      @initialized
    end

    def run_load_hooks! # :nodoc:
      return self if @ran_load_hooks
      @ran_load_hooks = true
      ActiveSupport.run_load_hooks(:before_configuration, self)

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

    # Returns the application's KeyGenerator
    def key_generator
      # number of iterations selected based on consultation with the google security
      # team. Details at https://github.com/rails/rails/pull/6952#issuecomment-7661220
      @caching_key_generator ||=
        if secrets.secret_key_base
          unless secrets.secret_key_base.kind_of?(String)
            raise ArgumentError, "`secret_key_base` for #{Rails.env} environment must be a type of String, change this value in `config/secrets.yml`"
          end
          key_generator = ActiveSupport::KeyGenerator.new(secrets.secret_key_base, iterations: 1000)
          ActiveSupport::CachingKeyGenerator.new(key_generator)
        else
          ActiveSupport::LegacyKeyGenerator.new(secrets.secret_token)
        end
    end

    # Returns a message verifier object.
    #
    # This verifier can be used to generate and verify signed messages in the application.
    #
    # It is recommended not to use the same verifier for different things, so you can get different
    # verifiers passing the +verifier_name+ argument.
    #
    # ==== Parameters
    #
    # * +verifier_name+ - the name of the message verifier.
    #
    # ==== Examples
    #
    #     message = Rails.application.message_verifier('sensitive_data').generate('my sensible data')
    #     Rails.application.message_verifier('sensitive_data').verify(message)
    #     # => 'my sensible data'
    #
    # See the +ActiveSupport::MessageVerifier+ documentation for more information.
    def message_verifier(verifier_name)
      @message_verifiers[verifier_name] ||= begin
        secret = key_generator.generate_key(verifier_name.to_s)
        ActiveSupport::MessageVerifier.new(secret)
      end
    end

    # Convenience for loading config/foo.yml for the current Rails env.
    #
    # Example:
    #
    #     # config/exception_notification.yml:
    #     production:
    #       url: http://127.0.0.1:8080
    #       namespace: my_app_production
    #     development:
    #       url: http://localhost:3001
    #       namespace: my_app_development
    #
    #     # config/environments/production.rb
    #     Rails.application.configure do
    #       config.middleware.use ExceptionNotifier, config_for(:exception_notification)
    #     end
    def config_for(name, env: Rails.env)
      if name.is_a?(Pathname)
        yaml = name
      else
        yaml = Pathname.new("#{paths["config"].existent.first}/#{name}.yml")
      end

      if yaml.exist?
        require "erb"
        (YAML.load(ERB.new(yaml.read).result) || {})[env] || {}
      else
        raise "Could not load configuration. No such file - #{yaml}"
      end
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{yaml}. " \
        "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
        "Error: #{e.message}"
    end

    # Stores some of the Rails initial environment parameters which
    # will be used by middlewares and engines to configure themselves.
    def env_config
      @app_env_config ||= begin
        validate_secret_key_config!

        super.merge(
          "action_dispatch.parameter_filter" => config.filter_parameters,
          "action_dispatch.redirect_filter" => config.filter_redirect,
          "action_dispatch.secret_token" => secrets.secret_token,
          "action_dispatch.secret_key_base" => secrets.secret_key_base,
          "action_dispatch.show_exceptions" => config.action_dispatch.show_exceptions,
          "action_dispatch.show_detailed_exceptions" => config.consider_all_requests_local,
          "action_dispatch.logger" => Rails.logger,
          "action_dispatch.backtrace_cleaner" => Rails.backtrace_cleaner,
          "action_dispatch.key_generator" => key_generator,
          "action_dispatch.http_auth_salt" => config.action_dispatch.http_auth_salt,
          "action_dispatch.signed_cookie_salt" => config.action_dispatch.signed_cookie_salt,
          "action_dispatch.encrypted_cookie_salt" => config.action_dispatch.encrypted_cookie_salt,
          "action_dispatch.encrypted_signed_cookie_salt" => config.action_dispatch.encrypted_signed_cookie_salt,
          "action_dispatch.cookies_serializer" => config.action_dispatch.cookies_serializer,
          "action_dispatch.cookies_digest" => config.action_dispatch.cookies_digest
        )
      end
    end

    # If you try to define a set of rake tasks on the instance, these will get
    # passed up to the rake tasks defined on the application's class.
    def rake_tasks(&block)
      self.class.rake_tasks(&block)
    end

    # Sends the initializers to the +initializer+ method defined in the
    # Rails::Initializable module. Each Rails::Application class has its own
    # set of initializers, as defined by the Initializable module.
    def initializer(name, opts={}, &block)
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
    def self.add_lib_to_load_path!(root) #:nodoc:
      path = File.join root, "lib"
      if File.exist?(path) && !$LOAD_PATH.include?(path)
        $LOAD_PATH.unshift(path)
      end
    end

    def require_environment! #:nodoc:
      environment = paths["config/environment"].existent.first
      require environment if environment
    end

    def routes_reloader #:nodoc:
      @routes_reloader ||= RoutesReloader.new
    end

    # Returns an array of file paths appended with a hash of
    # directories-extensions suitable for ActiveSupport::FileUpdateChecker
    # API.
    def watchable_args #:nodoc:
      files, dirs = config.watchable_files.dup, config.watchable_dirs.dup

      ActiveSupport::Dependencies.autoload_paths.each do |path|
        dirs[path.to_s] = [:rb]
      end

      [files, dirs]
    end

    # Initialize the application passing the given group. By default, the
    # group is :default
    def initialize!(group=:default) #:nodoc:
      raise "Application has been already initialized." if @initialized
      run_initializers(group, self)
      @initialized = true
      self
    end

    def initializers #:nodoc:
      Bootstrap.initializers_for(self) +
      railties_initializers(super) +
      Finisher.initializers_for(self)
    end

    def config #:nodoc:
      @config ||= Application::Configuration.new(self.class.find_root(self.class.called_from))
    end

    def config=(configuration) #:nodoc:
      @config = configuration
    end

    # Returns secrets added to config/secrets.yml.
    #
    # Example:
    #
    #     development:
    #       secret_key_base: 836fa3665997a860728bcb9e9a1e704d427cfc920e79d847d79c8a9a907b9e965defa4154b2b86bdec6930adbe33f21364523a6f6ce363865724549fdfc08553
    #     test:
    #       secret_key_base: 5a37811464e7d378488b0f073e2193b093682e4e21f5d6f3ae0a4e1781e61a351fdc878a843424e81c73fb484a40d23f92c8dafac4870e74ede6e5e174423010
    #     production:
    #       secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
    #       namespace: my_app_production
    #
    # +Rails.application.secrets.namespace+ returns +my_app_production+ in the
    # production environment.
    def secrets
      @secrets ||= begin
        secrets = ActiveSupport::OrderedOptions.new
        yaml    = config.paths["config/secrets"].first

        if File.exist?(yaml)
          require "erb"

          all_secrets    = YAML.load(ERB.new(IO.read(yaml)).result) || {}
          shared_secrets = all_secrets["shared"]
          env_secrets    = all_secrets[Rails.env]

          secrets.merge!(shared_secrets.symbolize_keys) if shared_secrets
          secrets.merge!(env_secrets.symbolize_keys) if env_secrets
        end

        # Fallback to config.secret_key_base if secrets.secret_key_base isn't set
        secrets.secret_key_base ||= config.secret_key_base
        # Fallback to config.secret_token if secrets.secret_token isn't set
        secrets.secret_token ||= config.secret_token

        secrets
      end
    end

    def secrets=(secrets) #:nodoc:
      @secrets = secrets
    end

    def to_app #:nodoc:
      self
    end

    def helpers_paths #:nodoc:
      config.helpers_paths
    end

    console do
      require "pp"
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

  protected

    alias :build_middleware_stack :app

    def run_tasks_blocks(app) #:nodoc:
      railties.each { |r| r.run_tasks_blocks(app) }
      super
      require "rails/tasks"
      task :environment do
        ActiveSupport.on_load(:before_initialize) { config.eager_load = false }

        require_environment!
      end
    end

    def run_generators_blocks(app) #:nodoc:
      railties.each { |r| r.run_generators_blocks(app) }
      super
    end

    def run_runner_blocks(app) #:nodoc:
      railties.each { |r| r.run_runner_blocks(app) }
      super
    end

    def run_console_blocks(app) #:nodoc:
      railties.each { |r| r.run_console_blocks(app) }
      super
    end

    # Returns the ordered railties for this application considering railties_order.
    def ordered_railties #:nodoc:
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

    def railties_initializers(current) #:nodoc:
      initializers = []
      ordered_railties.reverse.flatten.each do |r|
        if r == self
          initializers += current
        else
          initializers += r.initializers
        end
      end
      initializers
    end

    def default_middleware_stack #:nodoc:
      default_stack = DefaultMiddlewareStack.new(self, config, paths)
      default_stack.build_stack
    end

    def validate_secret_key_config! #:nodoc:
      if secrets.secret_key_base.blank?
        ActiveSupport::Deprecation.warn "You didn't set `secret_key_base`. " +
          "Read the upgrade documentation to learn more about this new config option."

        if secrets.secret_token.blank?
          raise "Missing `secret_key_base` for '#{Rails.env}' environment, set this value in `config/secrets.yml`"
        end
      end
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
  end
end
