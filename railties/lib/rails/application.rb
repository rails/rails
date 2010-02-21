require 'fileutils'
require 'rails/railties_path'
require 'rails/plugin'
require 'rails/engine'

module Rails
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
      alias   :configure :class_eval

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

    def require_environment!
      environment = config.paths.config.environment.to_a.first
      require environment if environment
    end

    def routes
      ::ActionDispatch::Routing::Routes
    end

    def railties
      @railties ||= Railties.new(config)
    end

    def metal_loader
      @metal_loader ||= MetalLoader.new
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
      super
      railties.all { |r| r.load_tasks }
      self
    end

    def load_generators
      initialize_generators
      super
      railties.all { |r| r.load_generators }
      self
    end

    def app
      @app ||= middleware.build(routes)
    end

    def call(env)
      env["action_dispatch.parameter_filter"] = config.filter_parameters
      app.call(env)
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
