require 'fileutils'

module Rails
  class Application < Engine
  
    # TODO Clear up 2 way delegation flow between App class and instance.
    # Infact just add a method_missing on the class.
    #
    # TODO I'd like to track the "default app" different using an inherited hook.
    class << self
      alias    :configure :class_eval
      delegate :initialize!, :load_tasks, :load_generators, :root, :to => :instance

      private :new
      def instance
        @instance ||= new
      end

      def config
        @config ||= Configuration.new(original_root)
      end

      def original_root
        @original_root ||= find_root_with_file_flag("config.ru", Dir.pwd)
      end

      def inherited(base)
        super
        Railtie.plugins.delete(base)
      end

      def routes
        ActionController::Routing::Routes
      end
    end

    delegate :routes, :to => :'self.class'
    attr_reader :route_configuration_files

    def initialize
      require_environment
      Rails.application ||= self
      @route_configuration_files = []
    end

    def initialize!
      run_initializers(self)
      self
    end
    
    def routes_changed_at
      routes_changed_at = nil

      route_configuration_files.each do |config|
        config_changed_at = File.stat(config).mtime

        if routes_changed_at.nil? || config_changed_at > routes_changed_at
          routes_changed_at = config_changed_at
        end
      end

      routes_changed_at
    end

    def reload_routes!
      routes = Rails::Application.routes
      routes.disable_clear_and_finalize = true

      routes.clear!
      route_configuration_files.each { |config| load(config) }
      routes.finalize!

      nil
    ensure
      routes.disable_clear_and_finalize = false
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
      @app ||= begin
        reload_routes!
        middleware.build(routes)
      end
    end

    def call(env)
      env["action_dispatch.parameter_filter"] = config.filter_parameters
      app.call(env)
    end

    def initializers
      my = super
      hook = my.index { |i| i.name == :set_autoload_paths } + 1
      initializers = Bootstrap.new(self).initializers
      initializers += my[0...hook]
      plugins.each { |p| initializers += p.initializers }
      initializers += my[hook..-1]
      initializers
    end

    initializer :add_builtin_route do |app|
      if Rails.env.development?
        app.route_configuration_files << File.join(RAILTIES_PATH, 'builtin', 'routes.rb')
      end
    end

    initializer :build_middleware_stack do
      app
    end

    # Fires the user-supplied after_initialize block (config#after_initialize)
    initializer :after_initialize do
      config.after_initialize_blocks.each do |block|
        block.call(self)
      end
    end

    # Disable dependency loading during request cycle
    initializer :disable_dependency_loading do
      if config.cache_classes && !config.dependency_loading
        ActiveSupport::Dependencies.unhook!
      end
    end
  end
end
