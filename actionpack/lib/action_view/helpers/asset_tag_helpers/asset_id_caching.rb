require 'active_support/concern'

module ActionView
  module Helpers
    module AssetTagHelper

      module AssetIdCaching
        extend ActiveSupport::Concern

        included do
          # You can enable or disable the asset tag timestamps cache.
          # With the cache enabled, the asset tag helper methods will make fewer
          # expensive file system calls. However this prevents you from modifying
          # any asset files while the server is running.
          #
          #   ActionView::Helpers::AssetTagHelper.cache_asset_timestamps = false
          mattr_accessor :cache_asset_timestamps

          private
          mattr_accessor :asset_timestamps_cache
          self.asset_timestamps_cache = {}

          mattr_accessor :asset_timestamps_cache_guard
          self.asset_timestamps_cache_guard = Mutex.new
        end

        private

          # Use the RAILS_ASSET_ID environment variable or the source's
          # modification time as its cache-busting asset id.
          def rails_asset_id(source)
            if asset_id = ENV["RAILS_ASSET_ID"]
              asset_id
            else
              if self.cache_asset_timestamps && (asset_id = self.asset_timestamps_cache[source])
                asset_id
              else
                path = File.join(config.assets_dir, source)
                asset_id = File.exist?(path) ? File.mtime(path).to_i.to_s : ''

                if self.cache_asset_timestamps
                  self.asset_timestamps_cache_guard.synchronize do
                    self.asset_timestamps_cache[source] = asset_id
                  end
                end

                asset_id
              end
            end
          end

          # Break out the asset path rewrite in case plugins wish to put the asset id
          # someplace other than the query string.
          # This is the default implementation
          def handle_asset_id(source)
            asset_id = rails_asset_id(source)
            if asset_id.empty?
              source
            else
              "#{source}?#{asset_id}"
            end
          end
      end

    end
  end
end