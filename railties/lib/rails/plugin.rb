module Rails
  class Plugin < Railtie
    def self.all(list, paths)
      plugins = []
      paths.each do |path|
        Dir["#{path}/*"].each do |plugin_path|
          plugin = new(plugin_path)
          next unless list.include?(plugin.name) || list.include?(:all)
          plugins << plugin
        end
      end

      plugins.sort_by do |p|
        [list.index(p.name) || list.index(:all), p.name.to_s]
      end
    end

    attr_reader :name, :path

    def initialize(path)
      @name = File.basename(path).to_sym
      @path = path
    end

    def load_paths
      Dir["#{path}/{lib}", "#{path}/app/{models,controllers,helpers}"]
    end

    def load_tasks
      Dir["#{path}/**/tasks/**/*.rake"].sort.each { |ext| load ext }
    end

    initializer :add_to_load_path, :after => :set_autoload_paths do |app|
      load_paths.each do |path|
        $LOAD_PATH << path
        require "active_support/dependencies"

        ActiveSupport::Dependencies.load_paths << path

        unless app.config.reload_plugins
          ActiveSupport::Dependencies.load_once_paths << path
        end
      end
    end

    initializer :load_init_rb, :before => :load_application_initializers do |app|
      file   = "#{@path}/init.rb"
      config = app.config
      eval File.read(file), binding, file if File.file?(file)
    end

    initializer :add_view_paths, :after => :initialize_framework_views do
      plugin_views = "#{path}/app/views"
      if File.directory?(plugin_views)
        ActionController::Base.view_paths.concat([plugin_views]) if defined? ActionController
        ActionMailer::Base.view_paths.concat([plugin_views])     if defined? ActionMailer
      end
    end

    # TODO Isn't it supposed to be :after => "action_controller.initialize_routing" ?
    initializer :add_routing_file, :after => :initialize_routing do |app|
      routing_file = "#{path}/config/routes.rb"
      if File.exist?(routing_file)
        app.route_configuration_files << routing_file
        app.reload_routes!
      end
    end
  end
end
