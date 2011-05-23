module Sprockets
  module Helpers
    module RailsHelper
      def asset_paths
        @asset_paths ||= begin
          config     = self.config if respond_to?(:config)
          controller = self.controller if respond_to?(:controller)
          RailsHelper::AssetPaths.new(config, controller)
        end
      end

      class AssetPaths < ActionView::Helpers::AssetPaths #:nodoc:
        def compute_public_path(source, dir, ext=nil, include_host=true)
          super(source, 'assets', ext, include_host)
        end

        def asset_for(source, ext)
          source = source.to_s
          return nil if is_uri?(source)
          source = rewrite_extension(source, nil, ext)
          assets[source]
        end

        def rewrite_asset_path(source, dir)
          if source[0] == ?/
            source
          else
            assets.path(source, performing_caching?, dir)
          end
        end

        def rewrite_extension(source, dir, ext)
          if ext && File.extname(source).empty?
            "#{source}.#{ext}"
          else
            source
          end
        end

        def assets
          Rails.application.assets
        end

        # When included in Sprockets::Context, we need to ask the top-level config as the controller is not available
        def performing_caching?
          @config ?  @config.perform_caching : Rails.application.config.action_controller.perform_caching
        end
      end
    end
  end
end
