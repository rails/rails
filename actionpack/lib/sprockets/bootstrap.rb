module Sprockets
  class Bootstrap
    def initialize(app)
      @app = app
    end

    # TODO: Get rid of config.assets.enabled
    def run
      app, config = @app, @app.config
      return unless app.assets

      config.assets.paths.each { |path| app.assets.append_path(path) }

      if config.assets.compress
        # temporarily hardcode default JS compressor to uglify. Soon, it will work
        # the same as SCSS, where a default plugin sets the default.
        unless config.assets.js_compressor == false
          app.assets.js_compressor = LazyCompressor.new { Sprockets::Compressors.registered_js_compressor(config.assets.js_compressor || :uglifier) }
        end

        unless config.assets.css_compressor == false
          app.assets.css_compressor = LazyCompressor.new { Sprockets::Compressors.registered_css_compressor(config.assets.css_compressor) }
        end
      end

      if config.assets.compile
        app.routes.prepend do
          mount app.assets => config.assets.prefix
        end
      end

      if config.assets.digest
        app.assets = app.assets.index
      end
    end
  end
end
