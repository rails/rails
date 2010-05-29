require 'rails/railtie/configuration'

module Rails
  class Engine
    class Configuration < ::Rails::Railtie::Configuration
      attr_reader :root
      attr_writer :eager_load_paths, :load_once_paths, :load_paths

      def initialize(root=nil)
        super()
        @root = root
      end

      def paths
        @paths ||= begin
          paths = Rails::Paths::Root.new(@root)
          paths.app                 "app",                 :eager_load => true, :glob => "*"
          paths.app.controllers     "app/controllers",     :eager_load => true
          paths.app.helpers         "app/helpers",         :eager_load => true
          paths.app.models          "app/models",          :eager_load => true
          paths.app.mailers         "app/mailers",         :eager_load => true
          paths.app.views           "app/views"
          paths.lib                 "lib",                 :load_path => true
          paths.lib.tasks           "lib/tasks",           :glob => "**/*.rake"
          paths.config              "config"
          paths.config.initializers "config/initializers", :glob => "**/*.rb"
          paths.config.locales      "config/locales",      :glob => "*.{rb,yml}"
          paths.config.routes       "config/routes.rb"
          paths.public              "public"
          paths.public.javascripts  "public/javascripts"
          paths.public.stylesheets  "public/stylesheets"
          paths
        end
      end

      def root=(value)
        @root = paths.path = Pathname.new(value).expand_path
      end

      def eager_load_paths
        @eager_load_paths ||= paths.eager_load
      end

      def load_once_paths
        @load_once_paths ||= paths.load_once
      end

      def load_paths
        @load_paths ||= paths.load_paths
      end
    end
  end
end