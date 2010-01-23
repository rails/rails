require 'fileutils'

module Rails
  class Application < Engine
    autoload :Bootstrap,      'rails/application/bootstrap'
    autoload :Finisher,       'rails/application/finisher'
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
        super
        Railtie.plugins.delete(base)
        Rails.application = base.instance
      end

    protected

      def method_missing(*args, &block)
        instance.send(*args, &block)
      end
    end

    def initialize
      require_environment
    end

    def routes
      ActionController::Routing::Routes
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

    def require_environment
      environment = config.paths.config.environment.to_a.first
      require environment if environment
    end

    def load_tasks
      require "rails/tasks"
      plugins.each { |p| p.load_tasks }
      # Load all application tasks
      # TODO: extract out the path to the rake tasks
      Dir["#{root}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
      task :environment do
        $rails_rake_task = true
        initialize!
      end
    end

    def load_generators
      plugins.each { |p| p.load_generators }
    end

    # TODO: Fix this method. It loads all railties independent if :all is given
    # or not, otherwise frameworks are never loaded.
    def plugins
      @plugins ||= begin
        plugin_names = (config.plugins || [:all]).map { |p| p.to_sym }
        Railtie.plugins.map(&:new) + Plugin.all(plugin_names, config.paths.vendor.plugins)
      end
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
      plugins.each { |p| initializers += p.initializers }
      initializers += Finisher.initializers
      initializers
    end
  end
end
