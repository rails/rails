require 'rails/engine'
require 'active_support/core_ext/array/conversions'

module Rails
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
        ActiveSupport::Deprecation.warn "Rake tasks in #{extra_tasks.to_sentence} are deprecated. Use lib/tasks instead"
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
      if File.file?(file = File.expand_path("rails/init.rb", root))
        ActiveSupport::Deprecation.warn "PLUGIN_PATH/rails/init.rb in plugins is deprecated. " <<
          "Use PLUGIN_PATH/init.rb instead"
      else
        file = File.expand_path("init.rb", root)
      end

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
