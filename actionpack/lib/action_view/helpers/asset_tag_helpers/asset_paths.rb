require 'thread'
require 'active_support/core_ext/file'

module ActionView
  module Helpers
    module AssetTagHelper

      class AssetPaths < ::ActionView::AssetPaths #:nodoc:
        # You can enable or disable the asset tag ids cache.
        # With the cache enabled, the asset tag helper methods will make fewer
        # expensive file system calls (the default implementation checks the file
        # system timestamp). However this prevents you from modifying any asset
        # files while the server is running.
        #
        #   ActionView::Helpers::AssetTagHelper::AssetPaths.cache_asset_ids = false
        mattr_accessor :cache_asset_ids

        # Add or change an asset id in the asset id cache. This can be used
        # for SASS on Heroku.
        # :api: public
        def add_to_asset_ids_cache(source, asset_id)
          self.asset_ids_cache_guard.synchronize do
            self.asset_ids_cache[source] = asset_id
          end
        end

      private

        def rewrite_extension(source, dir, ext)
          source_ext = File.extname(source)

          source_with_ext = if source_ext.empty?
            "#{source}.#{ext}"
          elsif ext != source_ext[1..-1]
            with_ext = "#{source}.#{ext}"
            with_ext if File.exist?(File.join(config.assets_dir, dir, with_ext))
          end

          source_with_ext || source
        end

        # Break out the asset path rewrite in case plugins wish to put the asset id
        # someplace other than the query string.
        def rewrite_asset_path(source, dir, options = nil)
          source = "/#{dir}/#{source}" unless source[0] == ?/
          path = config.asset_path

          if path && path.respond_to?(:call)
            return path.call(source)
          elsif path && path.is_a?(String)
            return path % [source]
          end

          asset_id = rails_asset_id(source)
          if asset_id.empty?
            source
          else
            "#{source}?#{asset_id}"
          end
        end

        mattr_accessor :asset_ids_cache
        self.asset_ids_cache = {}

        mattr_accessor :asset_ids_cache_guard
        self.asset_ids_cache_guard = Mutex.new

        # Use the RAILS_ASSET_ID environment variable or the source's
        # modification time as its cache-busting asset id.
        def rails_asset_id(source)
          if asset_id = ENV["RAILS_ASSET_ID"]
            asset_id
          else
            if self.cache_asset_ids && (asset_id = self.asset_ids_cache[source])
              asset_id
            else
              path = File.join(config.assets_dir, source)
              asset_id = File.exist?(path) ? File.mtime(path).to_i.to_s : ''

              if self.cache_asset_ids
                add_to_asset_ids_cache(source, asset_id)
              end

              asset_id
            end
          end
        end
      end

    end
  end
end
