module Sprockets
  autoload :Helpers, "sprockets/helpers"

  class Railtie < ::Rails::Railtie
    def self.using_coffee?
      require 'coffee-script'
      defined?(CoffeeScript)
    rescue LoadError
      false
    end

    config.app_generators.javascript_engine :coffee if using_coffee?

    # Configure ActionController to use sprockets.
    initializer "sprockets.set_configs", :after => "action_controller.set_configs" do |app|
      ActiveSupport.on_load(:action_controller) do
        self.use_sprockets = app.config.assets.enabled
      end
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
        env.paths.concat assets.paths

        env.logger = Rails.logger

        env.js_compressor  = expand_js_compressor(assets.js_compressor)
        env.css_compressor = expand_css_compressor(assets.css_compressor)

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
