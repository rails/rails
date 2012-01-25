module Sprockets
  class Bootstrap
    def initialize(app)
      @app = app
    end

    # TODO: Get rid of config.assets.enabled
    def run
      app, config = @app, @app.config

      app_assets = app.assets
      config_assets = config.assets

      return unless app_assets

      config_assets.paths.each { |path| app_assets.append_path(path) }

      if config_assets.compress
        # temporarily hardcode default JS compressor to uglify. Soon, it will work
        # the same as SCSS, where a default plugin sets the default.
        unless config_assets.js_compressor == false
          app_assets.js_compressor = LazyCompressor.new { Sprockets::Compressors.registered_js_compressor(config_assets.js_compressor || :uglifier) }
        end

        unless config_assets.css_compressor == false
          app_assets.css_compressor = LazyCompressor.new { Sprockets::Compressors.registered_css_compressor(config_assets.css_compressor) }
        end
      end

      if config_assets.compile
        app.routes.prepend do
          mount app_assets => config_assets.prefix
        end
      end

      if config_assets.digest
        app.assets = app_assets.index
      end
    end
  end
end
