module Rails
  class Plugin < Engine
    class << self
      def inherited(base)
        raise "You should not inherit from Rails::Plugin"
      end

      def config
        raise "Plugins does not provide configuration at the class level"
      end

      def all(list, paths)
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
    end

    attr_reader :name, :path

    def initialize(root)
      @name = File.basename(root).to_sym
      config.root = root
    end

    def config
      @config ||= Engine::Configuration.new
    end

    initializer :load_init_rb do |app|
      file   = Dir["#{root}/{rails/init,init}.rb"].first
      config = app.config
      eval(File.read(file), binding, file) if file && File.file?(file)
    end
  end
end
