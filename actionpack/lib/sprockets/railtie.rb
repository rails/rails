require "action_controller/railtie"

module Sprockets
  autoload :Bootstrap,      "sprockets/bootstrap"
  autoload :Helpers,        "sprockets/helpers"
  autoload :Compressors,    "sprockets/compressors"
  autoload :LazyCompressor, "sprockets/compressors"
  autoload :NullCompressor, "sprockets/compressors"
  autoload :StaticCompiler, "sprockets/static_compiler"

  # TODO: Get rid of config.assets.enabled
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "sprockets/assets.rake"
    end

    initializer "sprockets.environment", :group => :all do |app|
      config = app.config
      next unless config.assets.enabled

      require 'sprockets'

      app.assets = Sprockets::Environment.new(app.root.to_s) do |env|
        env.version = ::Rails.env + "-#{config.assets.version}"

        if config.assets.logger != false
          env.logger  = config.assets.logger || ::Rails.logger
        end

        if config.assets.cache_store != false
          env.cache = ActiveSupport::Cache.lookup_store(config.assets.cache_store) || ::Rails.cache
        end
      end

      if config.assets.manifest
        path = File.join(config.assets.manifest, "manifest.yml")
      else
        path = File.join(Rails.public_path, config.assets.prefix, "manifest.yml")
      end

      if File.exist?(path)
        config.assets.digests = YAML.load_file(path)
      end

      ActiveSupport.on_load(:action_view) do
        include ::Sprockets::Helpers::RailsHelper
        app.assets.context_class.instance_eval do
          include ::Sprockets::Helpers::IsolatedHelper
          include ::Sprockets::Helpers::RailsHelper
        end
      end
    end

    # We need to configure this after initialization to ensure we collect
    # paths from all engines. This hook is invoked exactly before routes
    # are compiled, and so that other Railties have an opportunity to
    # register compressors.
    config.after_initialize do |app|
      Sprockets::Bootstrap.new(app).run
    end
  end
end
