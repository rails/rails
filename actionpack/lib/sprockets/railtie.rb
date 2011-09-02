module Sprockets
  autoload :Helpers, "sprockets/helpers"
  autoload :LazyCompressor, "sprockets/compressors"
  autoload :NullCompressor, "sprockets/compressors"

  # TODO: Get rid of config.assets.enabled
  class Railtie < ::Rails::Railtie
    config.default_asset_host_protocol = :relative

    rake_tasks do
      load "sprockets/assets.rake"
    end

    initializer "sprockets.environment" do |app|
      config = app.config
      next unless config.assets.enabled

      require 'sprockets'

      app.assets = Sprockets::Environment.new(app.root.to_s) do |env|
        env.logger  = ::Rails.logger
        env.version = ::Rails.env + "-#{config.assets.version}"

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
          include ::Sprockets::Helpers::RailsHelper
        end
      end
    end

    # We need to configure this after initialization to ensure we collect
    # paths from all engines. This hook is invoked exactly before routes
    # are compiled, and so that other Railties have an opportunity to
    # register compressors.
    config.after_initialize do |app|
      next unless app.assets
      config = app.config

      config.assets.paths.each { |path| app.assets.append_path(path) }

      if config.assets.compress
        # temporarily hardcode default JS compressor to uglify. Soon, it will work
        # the same as SCSS, where a default plugin sets the default.
        unless config.assets.js_compressor == false
          app.assets.js_compressor = LazyCompressor.new { expand_js_compressor(config.assets.js_compressor || :uglifier) }
        end

        unless config.assets.css_compressor == false
          app.assets.css_compressor = LazyCompressor.new { expand_css_compressor(config.assets.css_compressor) }
        end
      end

      app.routes.prepend do
        mount app.assets => config.assets.prefix
      end

      if config.action_controller.perform_caching
        app.assets = app.assets.index
      end
    end

    protected
      def expand_js_compressor(sym)
        case sym
        when :closure
          require 'closure-compiler'
          Closure::Compiler.new
        when :uglifier
          require 'uglifier'
          Uglifier.new
        when :yui
          require 'yui/compressor'
          YUI::JavaScriptCompressor.new
        else
          sym
        end
      end

      def expand_css_compressor(sym)
        case sym
        when :yui
          require 'yui/compressor'
          YUI::CssCompressor.new
        else
          sym
        end
      end
  end
end
