require 'fileutils'

module Rails
  class Application < Engine
    autoload :Bootstrap,      'rails/application/bootstrap'
    autoload :Finisher,       'rails/application/finisher'
    autoload :Railties,       'rails/application/railties'
    autoload :RoutesReloader, 'rails/application/routes_reloader'

    # TODO Check helpers works as expected
    # TODO Check routes namespaces
    class << self
      private :new
      alias   :configure :class_eval

      def instance
        @instance ||= new
      end

      def config
        @config ||= Configuration.new(self.original_root)
      end

      def original_root
        @original_root ||= find_root_with_file_flag("config.ru", Dir.pwd)
      end

      def inherited(base)
        # TODO Add this check
        # raise "You cannot have more than one Rails::Application" if Rails.application
        super

        # TODO Add a test which ensures me
        # Railtie.plugins.delete(base)
        Rails.application ||= base.instance

        base.rake_tasks do
          require "rails/tasks"
          paths.lib.tasks.to_a.sort.each { |r| load(rake) }
          task :environment do
            $rails_rake_task = true
            initialize!
          end
        end
      end

    protected

      def method_missing(*args, &block)
        instance.send(*args, &block)
      end
    end

    # Application is always reloadable when config.cache_classes is false.
    def reloadable?(app)
      true
    end

    def initialize
      environment = config.paths.config.environment.to_a.first
      require environment if environment
    end

    def routes
      ::ActionController::Routing::Routes
    end

    def railties
      @railties ||= Railties.new(config)
    end

    def routes_reloader
      @routes_reloader ||= RoutesReloader.new(config)
    end

    def reload_routes!
      routes_reloader.reload!
    end

    def initialize!
      run_initializers(self)
      self
    end

    def load_tasks
      super
      railties.all { |r| r.load_tasks }
      self
    end

    def load_generators
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
      initializers = Bootstrap.initializers
      initializers += super
      railties.all { |r| initializers += r.initializers }
      initializers += Finisher.initializers
      initializers
    end
  end
end
