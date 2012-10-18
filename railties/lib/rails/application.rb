require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/file_update_checker'
require 'fileutils'
require 'rails/plugin'
require 'rails/engine'

module Rails
  # In Rails 3.0, a Rails::Application object was introduced which is nothing more than
  # an Engine but with the responsibility of coordinating the whole boot process.
  #
  # == Initialization
  #
  # Rails::Application is responsible for executing all railties, engines and plugin
  # initializers. It also executes some bootstrap initializers (check
  # Rails::Application::Bootstrap) and finishing initializers, after all the others
  # are executed (check Rails::Application::Finisher).
  #
  # == Configuration
  #
  # Besides providing the same configuration as Rails::Engine and Rails::Railtie,
  # the application object has several specific configurations, for example
  # "allow_concurrency", "cache_classes", "consider_all_requests_local", "filter_parameters",
  # "logger", "reload_plugins" and so forth.
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
  class Application < Engine
    autoload :Bootstrap,      'rails/application/bootstrap'
    autoload :Configuration,  'rails/application/configuration'
    autoload :Finisher,       'rails/application/finisher'
    autoload :Railties,       'rails/application/railties'
    autoload :RoutesReloader, 'rails/application/routes_reloader'

    class << self
      def inherited(base)
        raise "You cannot have more than one Rails::Application" if Rails.application
        super
        Rails.application = base.instance
        Rails.application.add_lib_to_load_path!
        ActiveSupport.run_load_hooks(:before_configuration, base.instance)
      end
    end

    attr_accessor :assets, :sandbox
    alias_method :sandbox?, :sandbox

    delegate :default_url_options, :default_url_options=, :to => :routes

    def initialize
      super
      @initialized = false
    end

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
    def add_lib_to_load_path! #:nodoc:
      path = config.root.join('lib').to_s
      $LOAD_PATH.unshift(path) if File.exists?(path)
    end

    def require_environment! #:nodoc:
      environment = paths["config/environment"].existent.first
      require environment if environment
    end

    def reload_routes!
      routes_reloader.reload!
    end

    def routes_reloader
      @routes_reloader ||= RoutesReloader.new
    end

    def initialize!(group=:default)
      raise "Application has been already initialized." if @initialized
      run_initializers(group, self)
      @initialized = true
      self
    end

    def load_tasks(app=self)
      initialize_tasks
      super
      self
    end

    def load_generators(app=self)
      initialize_generators
      super
      self
    end

    def load_console(app=self)
      initialize_console
      super
      self
    end

    def env_config
      @env_config ||= super.merge({
        "action_dispatch.parameter_filter" => config.filter_parameters,
        "action_dispatch.secret_token" => config.secret_token,
        "action_dispatch.show_exceptions" => config.action_dispatch.show_exceptions
      })
    end

    def initializers
      Bootstrap.initializers_for(self) +
      super +
      Finisher.initializers_for(self)
    end

    def config
      @config ||= Application::Configuration.new(find_root_with_flag("config.ru", Dir.pwd))
    end

    def to_app
      self
    end

    def call(env)
      env["ORIGINAL_FULLPATH"] = build_original_fullpath(env)
      super(env)
    end

  protected

    alias :build_middleware_stack :app

    def default_middleware_stack
      require 'action_controller/railtie'

      ActionDispatch::MiddlewareStack.new.tap do |middleware|
        if rack_cache = config.action_controller.perform_caching && config.action_dispatch.rack_cache
          require "action_dispatch/http/rack_cache"
          middleware.use ::Rack::Cache, rack_cache
        end

        if config.force_ssl
          require "rack/ssl"
          middleware.use ::Rack::SSL, config.ssl_options
        end

        if config.serve_static_assets
          middleware.use ::ActionDispatch::Static, paths["public"].first, config.static_cache_control
        end

        middleware.use ::Rack::Lock unless config.allow_concurrency
        middleware.use ::Rack::Runtime
        middleware.use ::Rack::MethodOverride
        middleware.use ::Rails::Rack::Logger # must come after Rack::MethodOverride to properly log overridden methods
        middleware.use ::ActionDispatch::ShowExceptions, config.consider_all_requests_local
        middleware.use ::ActionDispatch::RemoteIp, config.action_dispatch.ip_spoofing_check, config.action_dispatch.trusted_proxies
        middleware.use ::Rack::Sendfile, config.action_dispatch.x_sendfile_header
        middleware.use ::ActionDispatch::Reloader unless config.cache_classes
        middleware.use ::ActionDispatch::Callbacks
        middleware.use ::ActionDispatch::Cookies

        if config.session_store
          if config.force_ssl && !config.session_options.key?(:secure)
            config.session_options[:secure] = true
          end
          middleware.use config.session_store, config.session_options
          middleware.use ::ActionDispatch::Flash
        end

        middleware.use ::ActionDispatch::ParamsParser
        middleware.use ::ActionDispatch::Head
        middleware.use ::Rack::ConditionalGet
        middleware.use ::Rack::ETag, "no-cache"

        if config.action_dispatch.best_standards_support
          middleware.use ::ActionDispatch::BestStandardsSupport, config.action_dispatch.best_standards_support
        end
      end
    end

    def initialize_tasks
      self.class.rake_tasks do
        require "rails/tasks"
        task :environment do
          $rails_rake_task = true
          require_environment!
        end
      end
    end

    def initialize_generators
      require "rails/generators"
    end

    def initialize_console
      require "pp"
      require "rails/console/app"
      require "rails/console/helpers"
    end

    def build_original_fullpath(env)
      path_info    = env["PATH_INFO"]
      query_string = env["QUERY_STRING"]
      script_name  = env["SCRIPT_NAME"]

      if query_string.present?
        "#{script_name}#{path_info}?#{query_string}"
      else
        "#{script_name}#{path_info}"
      end
    end
  end
end
