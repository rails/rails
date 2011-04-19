require 'uri'

module ActionView
  module Helpers
    module SprocketsHelper
      def sprockets_asset_path(source, default_ext = nil)
        compute_sprockets_path(source, 'assets', default_ext)
      end

      def sprockets_javascript_path(source)
        sprockets_asset_path(source, 'js')
      end

      def sprockets_javascript_include_tag(source, options = {})
        options = {
          'type' => "text/javascript",
          'src'  => sprockets_javascript_path(source)
        }.merge(options.stringify_keys)

        content_tag 'script', "", options
      end

      def sprockets_stylesheet_path(source)
        sprockets_asset_path(source, 'css')
      end
      
      def sprockets_stylesheet_link_tag(source, options = {})
        options = {
          'rel'   => "stylesheet",
          'type'  => "text/css",
          'media' => "screen",
          'href'  => sprockets_stylesheet_path(source)
        }.merge(options.stringify_keys)

        tag 'link', options
      end


      private
        def compute_sprockets_path(source, dir, default_ext = nil)
          source = source.to_s

          return source if URI.parse(source).host

          # Add /assets to relative paths
          if source[0] != ?/
            source = "/#{dir}/#{source}"
          end

          # Add default extension if there isn't one
          if default_ext && File.extname(source).empty?
            source = "#{source}.#{default_ext}"
          end

          # Fingerprint url
          if source =~ /^\/#{dir}\/(.+)/
            source = assets.path($1, config.perform_caching, dir)
          end

          host = compute_asset_host(source)

          if controller.respond_to?(:request) && host && URI.parse(host).host
            source = "#{controller.request.protocol}#{host}#{source}"
          end

          source
        end

        def compute_asset_host(source)
          if host = config.asset_host
            if host.is_a?(Proc) || host.respond_to?(:call)
              case host.is_a?(Proc) ? host.arity : host.method(:call).arity
              when 2
                request = controller.respond_to?(:request) && controller.request
                host.call(source, request)
              else
                host.call(source)
              end
            else
              (host =~ /%d/) ? host % (source.hash % 4) : host
            end
          end
        end

        def assets
          Rails.application.assets
        end
    end
  end
end
