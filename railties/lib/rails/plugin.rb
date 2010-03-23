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
      load_deprecated_tasks
    end

    def load_deprecated_tasks
      tasks = Dir["#{root}/{tasks,rails/tasks}/**/*.rake"].sort
      if tasks.any?
        ActiveSupport::Deprecation.warn "Rake tasks in #{tasks.to_sentence} are deprecated. Use lib/tasks instead"
        tasks.each { |ext| load(ext) }
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
      lib_initializers = paths.lib.rails.initializers.to_a
      files = %w(rails/init.rb init.rb).map { |path| File.expand_path(path, root) }

      if lib_initializers.empty? && initrb = files.find { |path| File.file?(path) }
        ActiveSupport::Deprecation.warn "init.rb is deprecated: #{initrb}. Use lib/rails/initializers/#{name}.rb"
        config = app.config
        eval(File.read(initrb), binding, initrb)
      end
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
