require "action_view"

module Sprockets
  module Helpers
    module RailsHelper
      extend ActiveSupport::Concern
      include ActionView::Helpers::AssetTagHelper

      def asset_paths
        @asset_paths ||= begin
          paths = RailsHelper::AssetPaths.new(config, controller)
          paths.asset_environment = asset_environment
          paths.asset_digests     = asset_digests
          paths.compile_assets    = compile_assets?
          paths.digest_assets     = digest_assets?
          paths
        end
      end

      def javascript_include_tag(*sources)
        options = sources.extract_options!
        debug = options.key?(:debug) ? options.delete(:debug) : debug_assets?
        body  = options.key?(:body)  ? options.delete(:body)  : false
        digest  = options.key?(:digest)  ? options.delete(:digest)  : digest_assets?

        sources.collect do |source|
          if debug && asset = asset_paths.asset_for(source, 'js')
            asset.to_a.map { |dep|
              super(dep.pathname.to_s, { :src => path_to_asset(dep, :ext => 'js', :body => true, :digest => digest) }.merge!(options))
            }
          else
            super(source.to_s, { :src => path_to_asset(source, :ext => 'js', :body => body, :digest => digest) }.merge!(options))
          end
        end.uniq.join("\n").html_safe
      end

      def stylesheet_link_tag(*sources)
        options = sources.extract_options!
        debug   = options.key?(:debug) ? options.delete(:debug) : debug_assets?
        body    = options.key?(:body)  ? options.delete(:body)  : false
        digest  = options.key?(:digest)  ? options.delete(:digest)  : digest_assets?

        sources.collect do |source|
          if debug && asset = asset_paths.asset_for(source, 'css')
            asset.to_a.map { |dep|
              super(dep.pathname.to_s, { :href => path_to_asset(dep, :ext => 'css', :body => true, :protocol => :request, :digest => digest) }.merge!(options))
            }
          else
            super(source.to_s, { :href => path_to_asset(source, :ext => 'css', :body => body, :protocol => :request, :digest => digest) }.merge!(options))
          end
        end.uniq.join("\n").html_safe
      end

      def asset_path(source, options = {})
        source = source.logical_path if source.respond_to?(:logical_path)
        path = asset_paths.compute_public_path(source, asset_prefix, options.merge(:body => true))
        options[:body] ? "#{path}?body=1" : path
      end
      alias_method :path_to_asset, :asset_path # aliased to avoid conflicts with an asset_path named route

      def image_path(source)
        path_to_asset(source)
      end
      alias_method :path_to_image, :image_path # aliased to avoid conflicts with an image_path named route

      def font_path(source)
        path_to_asset(source)
      end
      alias_method :path_to_font, :font_path # aliased to avoid conflicts with an font_path named route

      def javascript_path(source)
        path_to_asset(source, :ext => 'js')
      end
      alias_method :path_to_javascript, :javascript_path # aliased to avoid conflicts with an javascript_path named route

      def stylesheet_path(source)
        path_to_asset(source, :ext => 'css')
      end
      alias_method :path_to_stylesheet, :stylesheet_path # aliased to avoid conflicts with an stylesheet_path named route

    private
      def debug_assets?
        compile_assets? && (Rails.application.config.assets.debug || params[:debug_assets])
      rescue NameError
        false
      end

      # Override to specify an alternative prefix for asset path generation.
      # When combined with a custom +asset_environment+, this can be used to
      # implement themes that can take advantage of the asset pipeline.
      #
      # If you only want to change where the assets are mounted, refer to
      # +config.assets.prefix+ instead.
      def asset_prefix
        Rails.application.config.assets.prefix
      end

      def asset_digests
        Rails.application.config.assets.digests
      end

      def compile_assets?
        Rails.application.config.assets.compile
      end

      def digest_assets?
        Rails.application.config.assets.digest
      end

      # Override to specify an alternative asset environment for asset
      # path generation. The environment should already have been mounted
      # at the prefix returned by +asset_prefix+.
      def asset_environment
        Rails.application.assets
      end

      class AssetPaths < ::ActionView::AssetPaths #:nodoc:
        attr_accessor :asset_environment, :asset_prefix, :asset_digests, :compile_assets, :digest_assets

        class AssetNotPrecompiledError < StandardError; end

        def asset_for(source, ext)
          source = source.to_s
          return nil if is_uri?(source)
          source = rewrite_extension(source, nil, ext)
          asset_environment[source]
        rescue Sprockets::FileOutsidePaths
          nil
        end

        def digest_for(logical_path)
          if digest_assets && asset_digests && (digest = asset_digests[logical_path])
            return digest
          end

          if compile_assets
            if digest_assets && asset = asset_environment[logical_path]
              return asset.digest_path
            end
            return logical_path
          else
            raise AssetNotPrecompiledError.new("#{logical_path} isn't precompiled")
          end
        end

        def rewrite_asset_path(source, dir, options = {})
          if source[0] == ?/
            source
          else
            source = digest_for(source) unless options[:digest] == false
            source = File.join(dir, source)
            source = "/#{source}" unless source =~ /^\//
            source
          end
        end

        def rewrite_extension(source, dir, ext)
          source_ext = File.extname(source)
          if ext && source_ext != ".#{ext}"
            if !source_ext.empty? && (asset = asset_environment[source]) &&
                  asset.pathname.to_s =~ /#{source}\Z/
              source
            else
              "#{source}.#{ext}"
            end
          else
            source
          end
        end
      end
    end
  end
end
