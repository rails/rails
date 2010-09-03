require 'rails/railtie/configuration'

module Rails
  class Engine
    class Configuration < ::Rails::Railtie::Configuration
      attr_reader :root
      attr_writer :eager_load_paths, :autoload_once_paths, :autoload_paths
      attr_accessor :middleware, :plugins, :asset_path

      def initialize(root=nil)
        super()
        @root = root
        @middleware = Rails::Configuration::MiddlewareStackProxy.new
        @helpers_paths = []
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
          paths.config.environments "config/environments", :glob => "#{Rails.env}.rb"
          paths.public              "public"
          paths.public.javascripts  "public/javascripts"
          paths.public.stylesheets  "public/stylesheets"
          paths.vendor              "vendor", :load_path => true
          paths.vendor.plugins      "vendor/plugins"
          paths.db                  "db"
          paths.db.migrate          "db/migrate"
          paths
        end
      end

      def root=(value)
        @root = paths.path = Pathname.new(value).expand_path
      end

      def eager_load_paths
        @eager_load_paths ||= paths.eager_load
      end

      def autoload_once_paths
        @autoload_once_paths ||= paths.autoload_once
      end

      def autoload_paths
        @autoload_paths ||= paths.autoload_paths
      end

      def compiled_asset_path
        asset_path % "" if asset_path
      end
    end
  end
end
