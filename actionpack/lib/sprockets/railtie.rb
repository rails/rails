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

    # We need to configure this after initialization to ensure we collect
    # paths from all engines. This hook is invoked exactly before routes
    # are compiled, and so that other Railties have an opportunity to
    # register compressors.
    config.after_initialize do |app|
      assets = app.config.assets
      next unless assets.enabled

      app.assets = asset_environment(app)

      ActiveSupport.on_load(:action_view) do
        include ::Sprockets::Helpers::RailsHelper

        app.assets.context_class.instance_eval do
          include ::Sprockets::Helpers::RailsHelper
        end
      end

      app.routes.prepend do
        mount app.assets => assets.prefix
      end

      if config.action_controller.perform_caching
        app.assets = app.assets.index
      end
    end

    protected
      def asset_environment(app)
        require "sprockets"

        assets = app.config.assets

        env = Sprockets::Environment.new(app.root.to_s)

        env.static_root = File.join(app.root.join("public"), assets.prefix)

        if env.respond_to?(:append_path)
          assets.paths.each { |path| env.append_path(path) }
        else
          env.paths.concat assets.paths
        end

        env.logger = ::Rails.logger

        if env.respond_to?(:cache) && assets.cache_store != false
          env.cache = ActiveSupport::Cache.lookup_store(assets.cache_store) || ::Rails.cache
        end

        if assets.compress
          # temporarily hardcode default JS compressor to uglify. Soon, it will work
          # the same as SCSS, where a default plugin sets the default.
          unless assets.js_compressor == false
            env.js_compressor  = LazyCompressor.new { expand_js_compressor(assets.js_compressor || :uglifier) }
          end

          unless assets.css_compressor == false
            env.css_compressor = LazyCompressor.new { expand_css_compressor(assets.css_compressor) }
          end
        end

        env
      end

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
