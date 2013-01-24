require 'rails/railtie/configuration'

module Rails
  class Engine
    class Configuration < ::Rails::Railtie::Configuration
      attr_reader :root
      attr_writer :middleware, :autoload_once_paths, :autoload_paths

      def initialize(root=nil)
        super()
        @root = root
        @generators = app_generators.dup
      end

      # Returns the middleware stack for the engine.
      def middleware
        @middleware ||= Rails::Configuration::MiddlewareStackProxy.new
      end

      # Holds generators configuration:
      #
      #   config.generators do |g|
      #     g.orm             :data_mapper, migration: true
      #     g.template_engine :haml
      #     g.test_framework  :rspec
      #   end
      #
      # If you want to disable color in console, do:
      #
      #   config.generators.colorize_logging = false
      #
      def generators #:nodoc:
        @generators ||= Rails::Configuration::Generators.new
        yield(@generators) if block_given?
        @generators
      end

      def paths
        @paths ||= begin
          paths = Rails::Paths::Root.new(@root)

          paths.add "app",                 autoload: true, glob: "*"
          paths.add "app/assets",          glob: "*"
          paths.add "app/controllers",     autoload: true
          paths.add "app/helpers",         autoload: true
          paths.add "app/models",          autoload: true
          paths.add "app/mailers",         autoload: true
          paths.add "app/views"

          paths.add "app/controllers/concerns", autoload: true
          paths.add "app/models/concerns",      autoload: true

          paths.add "lib",                 load_path: true
          paths.add "lib/assets",          glob: "*"
          paths.add "lib/tasks",           glob: "**/*.rake"

          paths.add "config"
          paths.add "config/environments", glob: "#{Rails.env}.rb"
          paths.add "config/initializers", glob: "**/*.rb"
          paths.add "config/locales",      glob: "*.{rb,yml}"
          paths.add "config/routes.rb"

          paths.add "db"
          paths.add "db/migrate"
          paths.add "db/seeds.rb"

          paths.add "vendor",              load_path: true
          paths.add "vendor/assets",       glob: "*"

          paths
        end
      end

      def root=(value)
        @root = paths.path = Pathname.new(value).expand_path
      end

      def eager_load_paths
        ActiveSupport::Deprecation.warn "eager_load_paths is deprecated and all autoload_paths are now eagerly loaded."
        autoload_paths
      end

      def eager_load_paths=(paths)
        ActiveSupport::Deprecation.warn "eager_load_paths is deprecated and all autoload_paths are now eagerly loaded."
        self.autoload_paths = paths
      end

      def autoload_once_paths
        @autoload_once_paths ||= paths.autoload_once
      end

      def autoload_paths
        @autoload_paths ||= paths.autoload_paths
      end
    end
  end
end
