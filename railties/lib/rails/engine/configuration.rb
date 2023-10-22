# frozen_string_literal: true

require "rails/railtie/configuration"

module Rails
  class Engine
    class Configuration < ::Rails::Railtie::Configuration
      attr_reader :root
      attr_accessor :middleware, :javascript_path
      attr_writer :eager_load_paths, :autoload_once_paths, :autoload_paths

      # An array of custom autoload paths to be added to the ones defined
      # automatically by Rails. These won't be eager loaded, unless you push
      # them to +eager_load_paths+ too, which is recommended.
      #
      # This collection is empty by default, it accepts strings and +Pathname+
      # objects.
      #
      # If you'd like to add +lib+ to it, please see +autoload_lib+.
      attr_reader :autoload_paths

      # An array of custom autoload once paths. These won't be eager loaded
      # unless you push them to +eager_load_paths+ too, which is recommended.
      #
      # This collection is empty by default, it accepts strings and +Pathname+
      # objects.
      #
      # If you'd like to add +lib+ to it, please see +autoload_lib_once+.
      attr_reader :autoload_once_paths

      # An array of custom eager load paths to be added to the ones defined
      # automatically by Rails. Anything in this collection is considered to be
      # an autoload path regardless of whether it was added to +autoload_paths+.
      #
      # This collection is empty by default, it accepts strings and +Pathname+
      # objects.
      #
      # If you'd like to add +lib+ to it, please see +autoload_lib+.
      attr_reader :eager_load_paths

      def initialize(root = nil)
        super()
        @root = root
        @generators = app_generators.dup
        @middleware = Rails::Configuration::MiddlewareStackProxy.new
        @javascript_path = "javascript"

        @autoload_paths = []
        @autoload_once_paths = []
        @eager_load_paths = []
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
      def generators
        @generators ||= Rails::Configuration::Generators.new
        yield(@generators) if block_given?
        @generators
      end

      def paths
        @paths ||= begin
          paths = Rails::Paths::Root.new(@root)

          paths.add "app",                 eager_load: true,
                                           glob: "{*,*/concerns}",
                                           exclude: ["assets", javascript_path]
          paths.add "app/assets",          glob: "*"
          paths.add "app/controllers",     eager_load: true
          paths.add "app/channels",        eager_load: true
          paths.add "app/helpers",         eager_load: true
          paths.add "app/models",          eager_load: true
          paths.add "app/mailers",         eager_load: true
          paths.add "app/views"

          # If you add more lib subdirectories here that should not be managed
          # by the main autoloader, please update the config.autoload_lib call
          # in the template that generates config/application.rb accordingly.
          paths.add "lib",                 load_path: true
          paths.add "lib/assets",          glob: "*"
          paths.add "lib/tasks",           glob: "**/*.rake"

          paths.add "config"
          paths.add "config/environments", glob: -"#{Rails.env}.rb"
          paths.add "config/initializers", glob: "**/*.rb"
          paths.add "config/locales",      glob: "**/*.{rb,yml}"
          paths.add "config/routes.rb"
          paths.add "config/routes",       glob: "**/*.rb"

          paths.add "db"
          paths.add "db/migrate"
          paths.add "db/seeds.rb"

          paths.add "vendor",              load_path: true
          paths.add "vendor/assets",       glob: "*"

          paths.add "test/mailers/previews", autoload: true

          paths
        end
      end

      def root=(value)
        @root = paths.path = Pathname.new(value).expand_path
      end

      # Private method that adds custom autoload paths to the ones defined by
      # +paths+.
      def all_autoload_paths # :nodoc:
        autoload_paths + paths.autoload_paths
      end

      # Private method that adds custom autoload once paths to the ones defined
      # by +paths+.
      def all_autoload_once_paths # :nodoc:
        autoload_once_paths + paths.autoload_once
      end

      # Private method that adds custom eager load paths to the ones defined by
      # +paths+.
      def all_eager_load_paths # :nodoc:
        eager_load_paths + paths.eager_load
      end
    end
  end
end
