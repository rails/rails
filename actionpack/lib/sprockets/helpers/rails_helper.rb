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
        options.merge!({:ext => "js"})
        asset_include_or_link_tag(sources, options) { |sources, options| super(sources, options) }
      end

      def stylesheet_link_tag(*sources)
        options = sources.extract_options!
        options.merge!(:ext => "css", :path_to_asset_options => { :protocol => :request })
        asset_include_or_link_tag(sources, options) { |sources, options| super(sources, options) }
      end

      def asset_path(source, options = {})
        source = source.logical_path if source.respond_to?(:logical_path)
        path = asset_paths.compute_public_path(source, asset_prefix, options.merge(:body => true))
        separator = (path =~ /\?/ ? "&" : "?")
        (options[:body] ? "#{path}#{separator}body=1" : path).html_safe
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
      def asset_include_or_link_tag(sources, options, &block)
        debug                 = options.delete(:debug)                 { debug_assets? }
        body                  = options.delete(:body)                  { false }
        digest                = options.delete(:digest)                { digest_assets? }
        path_to_asset_options = options.delete(:path_to_asset_options) { {} }
        params                = options.delete(:params)
        ext                   = options.delete(:ext)
        
        src_or_href_symbol    = ext == "js" ? :src : :href

        path_to_asset_options.merge!({ :ext => ext, 
                                       :body => body,
                                       :digest => digest, 
                                       :params => params })

        sources.collect do |source|
          if debug && asset = find_asset(source, ext)
            path_to_asset_options[:body] = true

            asset.to_a.map do |dep|
              block.call(dep.pathname.to_s, { src_or_href_symbol => path_to_asset(dep, path_to_asset_options) }.merge!(options))
            end
          else
            block.call(source.to_s, { src_or_href_symbol => path_to_asset(source, path_to_asset_options) }.merge!(options))
          end
        end.join("\n").html_safe
      end

      def find_asset(source, ext)
        source_without_ext = source.to_s.split(Regexp.new(".#{ext}")).first
        asset_paths.asset_for(source_without_ext, ext)
      end

      def debug_assets?
        compile_assets? && (Rails.application.config.assets.debug || params[:debug_assets])
      rescue NoMethodError
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
          source, query = source.split("?")

          params = options[:params].to_query if options[:params]
          params = (params.blank? ? query : "#{params}&#{query}") if query
            
          if source[0] != ?/
            source = digest_for(source.split("?").first) unless options[:digest] == false
            source = File.join(dir, source)
            source = "/#{source}" unless source =~ /^\//
          end

          params ? "#{source}?#{params}" : source
        end

        def rewrite_extension(source, dir, ext)
          if ext && (File.extname(source) =~ Regexp.new(".#{ext}")).nil?
            source, query = source.split("?")
            query = query.insert(0, "?") if query
            "#{source}.#{ext}#{query}"
          else
            source
          end
        end
      end
    end
  end
end
