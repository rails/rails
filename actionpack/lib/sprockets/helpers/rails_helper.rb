require "action_view/helpers/asset_paths"
require "action_view/helpers/asset_tag_helper"

module Sprockets
  module Helpers
    module RailsHelper
      extend ActiveSupport::Concern
      include ActionView::Helpers::AssetTagHelper
      
      def asset_paths
        @asset_paths ||= begin
          config     = self.config if respond_to?(:config)
          controller = self.controller if respond_to?(:controller)
          RailsHelper::AssetPaths.new(config, controller)
        end
      end

      def javascript_include_tag(*sources)
        options = sources.extract_options!
        debug = options.key?(:debug) ? options.delete(:debug) : debug_assets?
        body  = options.key?(:body)  ? options.delete(:body)  : false

        sources.collect do |source|
          if debug && asset = asset_paths.asset_for(source, 'js')
            asset.to_a.map { |dep|
              javascript_include_tag(dep, :debug => false, :body => true)
            }.join("\n").html_safe
          else
            tag_options = {
              'type' => "text/javascript",
              'src'  => asset_path(source, 'js', body)
            }.merge(options.stringify_keys)

            content_tag 'script', "", tag_options
          end
        end.join("\n").html_safe
      end

      def stylesheet_link_tag(*sources)
        options = sources.extract_options!
        debug = options.key?(:debug) ? options.delete(:debug) : debug_assets?
        body  = options.key?(:body)  ? options.delete(:body)  : false

        sources.collect do |source|
          if debug && asset = asset_paths.asset_for(source, 'css')
            asset.to_a.map { |dep|
              stylesheet_link_tag(dep, :debug => false, :body => true)
            }.join("\n").html_safe
          else
            tag_options = {
              'rel'   => "stylesheet",
              'type'  => "text/css",
              'media' => "screen",
              'href'  => asset_path(source, 'css', body)
            }.merge(options.stringify_keys)

            tag 'link', tag_options
          end
        end.join("\n").html_safe
      end

    private
      def debug_assets?
        params[:debug_assets] == '1' ||
          params[:debug_assets] == 'true'
      end

      def asset_path(source, default_ext = nil, body = false)
        source = source.logical_path if source.respond_to?(:logical_path)
        path = asset_paths.compute_public_path(source, 'assets', default_ext, true)
        body ? "#{path}?body=1" : path
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
