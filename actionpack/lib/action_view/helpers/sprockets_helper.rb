require 'uri'
require 'action_view/helpers/asset_tag_helpers/asset_paths'

module ActionView
  module Helpers
    module SprocketsHelper
      def asset_path(source, default_ext = nil)
        sprockets_asset_paths.compute_public_path(source, 'assets', default_ext, true)
      end

      def sprockets_javascript_include_tag(source, options = {})
        options = {
          'type' => "text/javascript",
          'src'  => asset_path(source, 'js')
        }.merge(options.stringify_keys)

        content_tag 'script', "", options
      end

      def sprockets_stylesheet_link_tag(source, options = {})
        options = {
          'rel'   => "stylesheet",
          'type'  => "text/css",
          'media' => "screen",
          'href'  => asset_path(source, 'css')
        }.merge(options.stringify_keys)

        tag 'link', options
      end

      private

      def sprockets_asset_paths
        @sprockets_asset_paths ||= begin
          config     = self.config if respond_to?(:config)
          controller = self.controller if respond_to?(:controller)
          SprocketsHelper::AssetPaths.new(config, controller)
        end
      end

      class AssetPaths < ActionView::Helpers::AssetTagHelper::AssetPaths
        def rewrite_asset_path(source, dir)
          if source =~ /^\/#{dir}\/(.+)/
            assets.path($1, performing_caching?, dir)
          else
            source
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

# FIXME: Temp hack for extending Sprockets::Context so 
class Sprockets::Context
  include ActionView::Helpers::SprocketsHelper
end if defined?(Sprockets)