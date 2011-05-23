require 'uri'
require 'action_view/helpers/asset_paths'

module ActionView
  module Helpers
    module SprocketsHelper
      def debug_assets?
        params[:debug_assets] == '1' ||
          params[:debug_assets] == 'true'
      end

      def asset_path(source, default_ext = nil, body = false)
        source = source.logical_path if source.respond_to?(:logical_path)
        path = asset_paths.compute_public_path(source, 'assets', default_ext, true)
        body ? "#{path}?body=1" : path
      end

      def sprockets_javascript_include_tag(source, options = {})
        debug = options.key?(:debug) ? options.delete(:debug) : debug_assets?
        body  = options.key?(:body)  ? options.delete(:body)  : false

        if debug && asset = asset_paths.asset_for(source, 'js')
          asset.to_a.map { |dep|
            sprockets_javascript_include_tag(dep, :debug => false, :body => true)
          }.join("\n").html_safe
        else
          options = {
            'type' => "text/javascript",
            'src'  => asset_path(source, 'js', body)
          }.merge(options.stringify_keys)

          content_tag 'script', "", options
        end
      end

      def sprockets_stylesheet_link_tag(source, options = {})
        debug = options.key?(:debug) ? options.delete(:debug) : debug_assets?
        body  = options.key?(:body)  ? options.delete(:body)  : false

        if debug && asset = asset_paths.asset_for(source, 'css')
          asset.to_a.map { |dep|
            sprockets_stylesheet_link_tag(dep, :debug => false, :body => true)
          }.join("\n").html_safe
        else
          options = {
            'rel'   => "stylesheet",
            'type'  => "text/css",
            'media' => "screen",
            'href'  => asset_path(source, 'css', body)
          }.merge(options.stringify_keys)

          tag 'link', options
        end
      end
    end
  end
end
