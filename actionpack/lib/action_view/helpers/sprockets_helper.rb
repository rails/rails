require 'uri'

module ActionView
  module Helpers
    module SprocketsHelper
      def asset_path(source, default_ext = nil)
        compute_sprockets_path(source, 'assets', default_ext)
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
        def compute_sprockets_path(source, dir, default_ext = nil)
          source = source.to_s

          unless source_is_a_url?(source)
            add_asset_directory(source, dir)
            add_default_extension(source, default_ext)
            add_fingerprint(source, dir)
            add_asset_host(source)
          end

          source
        end
        
        def add_asset_directory(source, dir)
          source.replace("/#{dir}/#{source}") if source[0] != ?/
        end
        
        def add_default_extension(source, default_ext)
          source.replace("#{source}.#{default_ext}") if default_ext && File.extname(source).empty?
        end
        
        def add_fingerprint(source, dir)
          if source =~ /^\/#{dir}\/(.+)/
            source.replace(assets.path($1, performing_caching?, dir))
          end
        end

        def add_asset_host(source)
          # When included in Sprockets::Context, there's no controller
          return unless respond_to?(:controller)

          host = compute_asset_host(source)

          if controller.respond_to?(:request) && host && URI.parse(host).host
            source.replace("#{controller.request.protocol}#{host}#{source}")
          end
        end
        
        def source_is_a_url?(source)
          URI.parse(source).host.present?
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
        
        def performing_caching?
          # When included in Sprockets::Context, we need to ask the top-level config as the controller is not available
          respond_to?(:config) ? config.perform_caching : Rails.application.config.action_controller.perform_caching
        end
    end
  end
end

# FIXME: Temp hack for extending Sprockets::Context so 
class Sprockets::Context
  include ActionView::Helpers::SprocketsHelper
end if defined?(Sprockets)