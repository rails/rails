require 'active_support/core_ext/hash/reverse_merge'
require 'fileutils'
require 'rails/plugin'
require 'rails/engine'

module Rails
  # In Rails 3.0, a Rails::Application object was introduced which is nothing more than
  # an Engine but with the responsibility of coordinating the whole boot process.
  #
  # Opposite to Rails::Engine, you can only have one Rails::Application instance
  # in your process and both Rails::Application and YourApplication::Application
  # points to it.
  #
  # In other words, Rails::Application is Singleton and whenever you are accessing
  # Rails::Application.config or YourApplication::Application.config, you are actually 
  # accessing YourApplication::Application.instance.config.
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
  # "logger", "metals", "reload_engines", "reload_plugins" and so forth.
  #
  # Check Rails::Application::Configuration to see them all.
  #
  # == Routes
  #
  # The application object is also responsible for holding the routes and reloading routes
  # whenever the files change in development.
  #
  # == Middlewares and metals
  #
  # The Application is also responsible for building the middleware stack and setting up
  # both application and engines metals.
  # 
  class Application < Engine
    autoload :Bootstrap,      'rails/application/bootstrap'
    autoload :Configurable,   'rails/application/configurable'
    autoload :Configuration,  'rails/application/configuration'
    autoload :Finisher,       'rails/application/finisher'
    autoload :MetalLoader,    'rails/application/metal_loader'
    autoload :Railties,       'rails/application/railties'
    autoload :RoutesReloader, 'rails/application/routes_reloader'

    class << self
      private :new

      def configure(&block)
        class_eval(&block)
      end

      def instance
        if self == Rails::Application
          Rails.application
        else
          @@instance ||= new
        end
      end

      def inherited(base)
        raise "You cannot have more than one Rails::Application" if Rails.application
        super
        Rails.application = base.instance
      end

      def respond_to?(*args)
        super || instance.respond_to?(*args)
      end

    protected

      def method_missing(*args, &block)
        instance.send(*args, &block)
      end
    end

    delegate :metal_loader, :to => :config

    def require_environment!
      environment = config.paths.config.environment.to_a.first
      require environment if environment
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end

    def railties
      @railties ||= Railties.new(config)
    end

    def routes_reloader
      @routes_reloader ||= RoutesReloader.new
    end

    def reload_routes!
      routes_reloader.reload!
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

    def app
      @app ||= middleware.build(routes)
    end

    def call(env)
      app.call(env.reverse_merge!(env_defaults))
    end

    def env_defaults
      @env_defaults ||= {
        "action_dispatch.parameter_filter" => config.filter_parameters,
        "action_dispatch.secret_token" => config.secret_token
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

    def initialize_tasks
      require "rails/tasks"
      task :environment do
        $rails_rake_task = true
        initialize!
      end
    end

    def initialize_generators
      require "rails/generators"
    end

    # Application is always reloadable when config.cache_classes is false.
    def reloadable?(app)
      true
    end
  end
end
