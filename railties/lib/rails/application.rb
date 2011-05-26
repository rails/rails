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
  # initializers. Besides, it also executed some bootstrap initializers (check
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
    autoload :Configurable,   'rails/application/configurable'
    autoload :Configuration,  'rails/application/configuration'
    autoload :Finisher,       'rails/application/finisher'
    autoload :Railties,       'rails/application/railties'

    class << self
      private :new

      def configure(&block)
        class_eval(&block)
      end

      def instance
        if self == Rails::Application
          if Rails.application
            ActiveSupport::Deprecation.warn "Calling a method in Rails::Application is deprecated, " <<
              "please call it directly in your application constant #{Rails.application.class.name}.", caller
          end
          Rails.application
        else
          @@instance ||= new
        end
      end

      def inherited(base)
        raise "You cannot have more than one Rails::Application" if Rails.application
        super
        Rails.application = base.instance
        Rails.application.add_lib_to_load_path!
        ActiveSupport.run_load_hooks(:before_configuration, base.instance)
      end

      def respond_to?(*args)
        super || instance.respond_to?(*args)
      end

    protected

      def method_missing(*args, &block)
        instance.send(*args, &block)
      end
    end

    delegate :middleware, :to => :config

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
      environment = paths.config.environment.to_a.first
      require environment if environment
    end

    def eager_load! #:nodoc:
      railties.all(&:eager_load!)
      super
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end

    def railties
      @railties ||= Railties.new(config)
    end

    def routes_reloader
      @routes_reloader ||= ActiveSupport::FileUpdateChecker.new([]){ reload_routes! }
    end

    def reload_routes!
      _routes = self.routes
      _routes.disable_clear_and_finalize = true
      _routes.clear!
      routes_reloader.paths.each { |path| load(path) }
      ActiveSupport.on_load(:action_controller) { _routes.finalize! }
    ensure
      _routes.disable_clear_and_finalize = false
    end

    def initialize!
      run_initializers(self)
      self
    end

    def load_tasks
      initialize_tasks
      railties.all { |r| r.load_tasks }
      super
      self
    end

    def load_generators
      initialize_generators
      railties.all { |r| r.load_generators }
      super
      self
    end

    def load_console(sandbox=false)
      initialize_console(sandbox)
      railties.all { |r| r.load_console }
      super()
      self
    end

    def app
      @app ||= begin
        config.middleware = config.middleware.merge_into(default_middleware_stack)
        config.middleware.build(routes)
      end
    end
    alias :build_middleware_stack :app

    def call(env)
      app.call(env.reverse_merge!(env_defaults))
    end

    def env_defaults
      @env_defaults ||= {
        "action_dispatch.parameter_filter" => config.filter_parameters,
        "action_dispatch.secret_token" => config.secret_token,
        "action_dispatch.show_exceptions" => config.action_dispatch.show_exceptions
      }
    end

    def initializers
      initializers = Bootstrap.initializers_for(self)
      railties.all { |r| initializers += r.initializers }
      initializers += super
      initializers += Finisher.initializers_for(self)
      initializers
    end

  protected

    def default_middleware_stack
      ActionDispatch::MiddlewareStack.new.tap do |middleware|
        middleware.use ::ActionDispatch::Static, paths.public.to_a.first if config.serve_static_assets
        middleware.use ::Rack::Lock if !config.allow_concurrency
        middleware.use ::Rack::Runtime
        middleware.use ::Rails::Rack::Logger
        middleware.use ::ActionDispatch::ShowExceptions, config.consider_all_requests_local
        middleware.use ::ActionDispatch::RemoteIp, config.action_dispatch.ip_spoofing_check, config.action_dispatch.trusted_proxies
        middleware.use ::Rack::Sendfile, config.action_dispatch.x_sendfile_header
        middleware.use ::ActionDispatch::Callbacks, !config.cache_classes
        middleware.use ::ActionDispatch::Cookies

        if config.session_store
          middleware.use config.session_store, config.session_options
          middleware.use ::ActionDispatch::Flash
        end

        middleware.use ::ActionDispatch::ParamsParser
        middleware.use ::Rack::MethodOverride
        middleware.use ::ActionDispatch::Head
        middleware.use ::ActionDispatch::BestStandardsSupport, config.action_dispatch.best_standards_support if config.action_dispatch.best_standards_support
      end
    end

    def initialize_tasks
      extend Rake::DSL if defined? Rake::DSL
      require "rails/tasks"
      task :environment do
        $rails_rake_task = true
        require_environment!
      end
    end

    def initialize_generators
      require "rails/generators"
    end

    def initialize_console(sandbox=false)
      require "rails/console/app"
      require "rails/console/sandbox" if sandbox
      require "rails/console/helpers"
    end
  end
end
