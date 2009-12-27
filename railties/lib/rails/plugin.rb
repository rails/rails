module Rails
  class Plugin
    include Initializable

    def self.plugin_name(plugin_name = nil)
      @plugin_name ||= name.demodulize.underscore
      @plugin_name = plugin_name if plugin_name
      @plugin_name
    end

    def self.inherited(klass)
      @plugins ||= []
      @plugins << klass unless klass == Vendored
    end

    def self.plugins
      @plugins
    end

    def self.plugin_names
      plugins.map { |p| p.plugin_name }
    end

    def self.config
      Configuration.default
    end

    # Creates an initializer which includes all given modules to the given class.
    #
    #   module Rails
    #     class ActionController < Rails::Plugin
    #       plugin_name :action_controller
    #       include_modules_in "ActionController::Base"
    #     end
    #   end
    #
    def self.include_modules_in(klass, from=plugin_name)
      self.initializer :"#{from}.include_modules" do |app|
        klass = klass.constantize if klass.is_a?(String)
        app.config.send(from).includes.each do |mod|
          klass.send(:include, mod.is_a?(String) ? mod.constantize : mod)
        end
      end
    end

    class Vendored < Plugin
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
        ActionController::Base.view_paths.concat ["#{path}/app/views"] if File.directory?("#{path}/app/views")
      end

      initializer :add_routing_file, :after => :initialize_routing do |app|
        routing_file = "#{path}/config/routes.rb"
        if File.exist?(routing_file)
          app.route_configuration_files << routing_file
          app.reload_routes!
        end
      end
    end
  end
end