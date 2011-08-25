require 'rails/engine'
require 'active_support/core_ext/array/conversions'

module Rails
  # Rails::Plugin is nothing more than a Rails::Engine, but since it's loaded too late
  # in the boot process, it does not have the same configuration powers as a bare
  # Rails::Engine.
  #
  # Opposite to Rails::Railtie and Rails::Engine, you are not supposed to inherit from
  # Rails::Plugin. Rails::Plugin is automatically configured to be an engine by simply
  # placing inside vendor/plugins. Since this is done automatically, you actually cannot
  # declare a Rails::Engine inside your Plugin, otherwise it would cause the same files
  # to be loaded twice. This means that if you want to ship an Engine as gem it cannot
  # be used as plugin and vice-versa.
  #
  # Besides this conceptual difference, the only difference between Rails::Engine and
  # Rails::Plugin is that plugins automatically load the file "init.rb" at the plugin
  # root during the boot process.
  #
  class Plugin < Engine
    def self.global_plugins
      @global_plugins ||= []
    end

    def self.inherited(base)
      raise "You cannot inherit from Rails::Plugin"
    end

    def self.all(list, paths)
      plugins = []
      paths.each do |path|
        Dir["#{path}/*"].each do |plugin_path|
          plugin = new(plugin_path)
          next unless list.include?(plugin.name) || list.include?(:all)
          if global_plugins.include?(plugin.name)
            warn "WARNING: plugin #{plugin.name} from #{path} was not loaded. Plugin with the same name has been already loaded."
            next
          end
          global_plugins << plugin.name
          plugins << plugin
        end
      end

      plugins.sort_by do |p|
        [list.index(p.name) || list.index(:all), p.name.to_s]
      end
    end

    attr_reader :name, :path

    def railtie_name
      name.to_s
    end

    def initialize(root)
      @name = File.basename(root).to_sym
      config.root = root
    end

    def config
      @config ||= Engine::Configuration.new
    end

    initializer :handle_lib_autoload, :before => :set_load_path do |app|
      autoload = if app.config.reload_plugins
        config.autoload_paths
      else
        config.autoload_once_paths
      end

      autoload.concat paths["lib"].existent
    end

    initializer :load_init_rb, :before => :load_config_initializers do |app|
      init_rb = File.expand_path("init.rb", root)
      if File.file?(init_rb)
        # This double assignment is to prevent an "unused variable" warning on Ruby 1.9.3.
        config = config = app.config
        # TODO: think about evaling initrb in context of Engine (currently it's
        # always evaled in context of Rails::Application)
        eval(File.read(init_rb), binding, init_rb)
      end
    end

    initializer :sanity_check_railties_collision do
      if Engine.subclasses.map { |k| k.root.to_s }.include?(root.to_s)
        raise "\"#{name}\" is a Railtie/Engine and cannot be installed as a plugin"
      end
    end
  end
end
