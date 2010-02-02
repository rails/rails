require 'rails/engine'

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
    def self.inherited(base)
      raise "You cannot inherit from Rails::Plugin"
    end

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

    def load_tasks
      super
      extra_tasks = Dir["#{root}/{tasks,rails/tasks}/**/*.rake"]

      unless extra_tasks.empty?
        ActiveSupport::Deprecation.warn "Having rake tasks in PLUGIN_PATH/tasks or " <<
          "PLUGIN_PATH/rails/tasks is deprecated. Use to PLUGIN_PATH/lib/tasks instead"
        extra_tasks.sort.each { |ext| load(ext) }
      end
    end

    def initialize(root)
      @name = File.basename(root).to_sym
      config.root = root
    end

    def config
      @config ||= Engine::Configuration.new
    end

    initializer :load_init_rb, :before => :load_application_initializers do |app|
      file   = Dir["#{root}/{rails/init,init}.rb"].first
      config = app.config
      eval(File.read(file), binding, file) if file && File.file?(file)
    end

    initializer :sanity_check_railties_collision do
      if Engine.subclasses.map { |k| k.root.to_s }.include?(root.to_s)
        raise "\"#{name}\" is a Railtie/Engine and cannot be installed as plugin"
      end
    end

  protected

    def reloadable?(app)
      app.config.reload_plugins
    end
  end
end
