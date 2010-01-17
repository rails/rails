require "fileutils"
require 'active_support/core_ext/module/delegation'

module Rails
  class Application
    include Initializable

    class << self
      attr_writer :config
      alias configure class_eval
      delegate :initialize!, :load_tasks, :root, :to => :instance

      private :new
      def instance
        @instance ||= new
      end

      def config
        @config ||= Configuration.new(Plugin::Configuration.default)
      end

      def routes
        ActionController::Routing::Routes
      end
    end

    delegate :config, :routes, :to => :'self.class'
    delegate :root, :middleware, :to => :config
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

    def require_environment
      require config.environment_path
    rescue LoadError
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
      routes.disable_clear_and_finalize = true

      routes.clear!
      route_configuration_files.each { |config| load(config) }
      routes.finalize!

      nil
    ensure
      routes.disable_clear_and_finalize = false
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

    def initializers
      initializers = Bootstrap.new(self).initializers
      plugins.each { |p| initializers += p.initializers }
      initializers += super
      initializers
    end

    # TODO: Fix this method
    def plugins
      @plugins ||= begin
        plugin_names = (config.plugins || [:all]).map { |p| p.to_sym }
        Railtie.plugins.select { |p|
          plugin_names.include?(:all) || plugin_names.include?(p.plugin_name)
        }.map { |p| p.new } + Plugin.all(plugin_names, config.paths.vendor.plugins)
      end
    end

    def app
      @app ||= begin
        reload_routes!
        middleware.build(routes)
      end
    end

    def call(env)
      app.call(env)
    end

    initializer :load_application_initializers do
      Dir["#{root}/config/initializers/**/*.rb"].sort.each do |initializer|
        load(initializer)
      end
    end

    initializer :build_middleware_stack do
      app
    end

    # Fires the user-supplied after_initialize block (Configuration#after_initialize)
    initializer :after_initialize do
      config.after_initialize_blocks.each do |block|
        block.call
      end
    end

    # Eager load application classes
    initializer :load_application_classes do
      next if $rails_rake_task

      if config.cache_classes
        config.eager_load_paths.each do |load_path|
          matcher = /\A#{Regexp.escape(load_path)}(.*)\.rb\Z/
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1')
          end
        end
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
